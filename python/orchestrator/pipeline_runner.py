#!/usr/bin/env python3
"""
Multi-Dataset Pipeline Orchestrator

Automated processing of multiple police search datasets with:
- Global reason classification cache for cost optimization
- Parallel dataset processing
- Comprehensive error handling and logging
- Cost tracking and analytics

Usage:
  python pipeline_runner.py --config-file datasets.json
  python pipeline_runner.py --dry-run
  python pipeline_runner.py --parallel --max-workers 3
  python pipeline_runner.py --sequential

Author: Colin
Date: 2025
"""

import argparse
import logging
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import List, Dict, Optional
from datetime import datetime

from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('pipeline_execution.log')
    ]
)
logger = logging.getLogger(__name__)


@dataclass
class DatasetConfig:
    """Configuration for a single dataset"""
    config_id: str
    dataset_name: str
    source_table_name: str
    enabled: bool
    priority: int
    owner: str


@dataclass
class ExecutionResult:
    """Result of processing a single dataset"""
    config_id: str
    status: str  # 'SUCCESS', 'ERROR', 'SKIPPED'
    duration: float
    error: Optional[str] = None
    rows_processed: Optional[int] = None


class PipelineOrchestrator:
    """Manages automated processing of multiple datasets"""

    PROJECT_ID = 'durango-deflock'
    DATASET_ID = 'FlockML'
    CONFIG_TABLE = 'dataset_pipeline_config'

    def __init__(self, parallel: bool = False, max_workers: int = 3, dry_run: bool = False):
        """
        Initialize the orchestrator

        Args:
            parallel: Whether to process datasets in parallel
            max_workers: Maximum number of parallel workers
            dry_run: If True, show what would be processed without executing
        """
        self.client = bigquery.Client(project=self.PROJECT_ID)
        self.parallel = parallel
        self.max_workers = max_workers
        self.dry_run = dry_run
        self.results: List[ExecutionResult] = []

    def get_enabled_datasets(self) -> List[DatasetConfig]:
        """Fetch enabled datasets from configuration table"""
        query = f"""
        SELECT config_id, dataset_name, source_table_name, enabled, priority, owner
        FROM `{self.PROJECT_ID}.{self.DATASET_ID}.{self.CONFIG_TABLE}`
        WHERE enabled = TRUE
        ORDER BY priority ASC
        """
        try:
            results = self.client.query(query).result()
            datasets = [
                DatasetConfig(
                    config_id=row['config_id'],
                    dataset_name=row['dataset_name'],
                    source_table_name=row['source_table_name'],
                    enabled=row['enabled'],
                    priority=row['priority'],
                    owner=row['owner']
                )
                for row in results
            ]
            logger.info(f"Loaded {len(datasets)} enabled datasets from config")
            return datasets
        except GoogleCloudError as e:
            logger.error(f"Failed to fetch datasets: {e}")
            raise

    def process_single_dataset(self, config_id: str) -> ExecutionResult:
        """Process a single dataset using BigQuery procedure"""
        start_time = time.time()
        query = f"""
        CALL `{self.PROJECT_ID}.{self.DATASET_ID}.sp_process_single_dataset`('{config_id}')
        """

        logger.info(f"Starting processing: {config_id}")

        try:
            # Run the procedure
            job = self.client.query(query)
            job.result()  # Wait for completion
            duration = time.time() - start_time

            logger.info(f"✓ Completed {config_id} in {duration:.1f}s")
            return ExecutionResult(
                config_id=config_id,
                status='SUCCESS',
                duration=duration
            )
        except GoogleCloudError as e:
            duration = time.time() - start_time
            error_msg = str(e)
            logger.error(f"✗ Failed {config_id}: {error_msg}")
            return ExecutionResult(
                config_id=config_id,
                status='ERROR',
                duration=duration,
                error=error_msg
            )

    def process_datasets_sequential(self, datasets: List[DatasetConfig]) -> List[ExecutionResult]:
        """Process datasets one by one"""
        logger.info(f"Processing {len(datasets)} datasets sequentially...")
        results = []
        for ds in datasets:
            result = self.process_single_dataset(ds.config_id)
            results.append(result)
        return results

    def process_datasets_parallel(self, datasets: List[DatasetConfig]) -> List[ExecutionResult]:
        """Process datasets in parallel"""
        logger.info(f"Processing {len(datasets)} datasets in parallel (max_workers={self.max_workers})...")
        results = []

        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_config = {
                executor.submit(self.process_single_dataset, ds.config_id): ds
                for ds in datasets
            }

            for future in as_completed(future_to_config):
                result = future.result()
                results.append(result)

        return results

    def print_summary(self, datasets: List[DatasetConfig], results: List[ExecutionResult]):
        """Print execution summary"""
        successful = sum(1 for r in results if r.status == 'SUCCESS')
        failed = sum(1 for r in results if r.status == 'ERROR')
        total_duration = sum(r.duration for r in results)

        print("\n" + "=" * 70)
        print("PIPELINE EXECUTION SUMMARY")
        print("=" * 70)
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Mode: {'PARALLEL' if self.parallel else 'SEQUENTIAL'}")
        print(f"Dry Run: {self.dry_run}")
        print(f"\nResults:")
        print(f"  Total Datasets: {len(datasets)}")
        print(f"  Successful: {successful}")
        print(f"  Failed: {failed}")
        print(f"  Total Duration: {total_duration:.1f}s")

        if results:
            print(f"\nDetails:")
            for result in results:
                status_icon = "✓" if result.status == 'SUCCESS' else "✗"
                print(f"  {status_icon} {result.config_id}: {result.status} ({result.duration:.1f}s)")
                if result.error:
                    print(f"     Error: {result.error[:80]}...")

        print("=" * 70 + "\n")

    def run(self):
        """Main orchestration entry point"""
        datasets = self.get_enabled_datasets()

        if not datasets:
            logger.warning("No enabled datasets found in configuration")
            return

        if self.dry_run:
            print("\n" + "=" * 70)
            print("DRY RUN: Would process the following datasets:")
            print("=" * 70)
            for ds in datasets:
                print(f"  [{ds.priority:02d}] {ds.config_id}: {ds.dataset_name}.{ds.source_table_name}")
            print("=" * 70 + "\n")
            return

        # Process datasets
        if self.parallel:
            results = self.process_datasets_parallel(datasets)
        else:
            results = self.process_datasets_sequential(datasets)

        self.results = results
        self.print_summary(datasets, results)

        # Exit with error code if any failures
        if any(r.status == 'ERROR' for r in results):
            sys.exit(1)


def main():
    """Entry point"""
    parser = argparse.ArgumentParser(
        description='Automated Multi-Dataset Processing Pipeline',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Process all datasets sequentially
  python pipeline_runner.py

  # Dry run to see what would be processed
  python pipeline_runner.py --dry-run

  # Process in parallel with 3 workers
  python pipeline_runner.py --parallel --max-workers 3
        """
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be processed without executing'
    )

    parser.add_argument(
        '--parallel',
        action='store_true',
        help='Process datasets in parallel'
    )

    parser.add_argument(
        '--sequential',
        action='store_true',
        help='Process datasets sequentially (default)'
    )

    parser.add_argument(
        '--max-workers',
        type=int,
        default=3,
        help='Max parallel workers (default: 3)'
    )

    args = parser.parse_args()

    # Default to sequential if neither --parallel nor --sequential specified
    parallel = args.parallel and not args.sequential

    orchestrator = PipelineOrchestrator(
        parallel=parallel,
        max_workers=args.max_workers,
        dry_run=args.dry_run
    )

    try:
        orchestrator.run()
    except KeyboardInterrupt:
        logger.info("Pipeline interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Pipeline failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
