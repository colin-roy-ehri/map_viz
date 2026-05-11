#!/usr/bin/env python3
"""
Dataset Registration Helper

Register new datasets in the pipeline configuration table.
Once registered, datasets will be automatically processed by the orchestrator.

Usage:
  python register_dataset.py --dataset DurangoPD --table November2025
  python register_dataset.py --dataset TelluridePD --table October2025 --priority 10
  python register_dataset.py --list  # List all configured datasets

Author: Colin
Date: 2025
"""

import argparse
import logging
import sys
from datetime import datetime
from typing import Optional, List

from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DatasetRegistry:
    """Manage dataset registration in the pipeline"""

    PROJECT_ID = 'durango-deflock'
    DATASET_ID = 'FlockML'
    CONFIG_TABLE = 'dataset_pipeline_config'

    def __init__(self):
        self.client = bigquery.Client(project=self.PROJECT_ID)

    def register_dataset(
        self,
        dataset_name: str,
        table_name: str,
        priority: int = 100,
        owner: str = 'colin',
        enabled: bool = True
    ) -> bool:
        """Register a new dataset in the pipeline configuration"""
        config_id = f"{dataset_name.lower()}-{table_name.lower()}".replace(' ', '-')

        # Construct the full table name
        source_table_name = f"{dataset_name}.{table_name}"

        query = f"""
        INSERT INTO `{self.PROJECT_ID}.{self.DATASET_ID}.{self.CONFIG_TABLE}`
        (config_id, dataset_project, dataset_name, source_table_name,
         enabled, priority, output_dataset_name, output_suffix,
         description, owner, created_timestamp)
        VALUES (
          '{config_id}',
          '{self.PROJECT_ID}',
          '{dataset_name}',
          '{table_name}',
          {str(enabled).upper()},
          {priority},
          NULL,
          '_classified',
          '{dataset_name} {table_name} dataset',
          '{owner}',
          CURRENT_TIMESTAMP()
        )
        """

        try:
            self.client.query(query).result()
            logger.info(f"✓ Registered dataset: {dataset_name}.{table_name}")
            logger.info(f"  Config ID: {config_id}")
            logger.info(f"  Priority: {priority}")
            logger.info(f"  Owner: {owner}")
            logger.info(f"  Enabled: {enabled}")
            return True
        except GoogleCloudError as e:
            logger.error(f"Failed to register dataset: {e}")
            return False

    def list_datasets(self) -> List[dict]:
        """List all configured datasets"""
        query = f"""
        SELECT
          config_id,
          dataset_name,
          source_table_name,
          enabled,
          priority,
          owner,
          created_timestamp,
          last_processed_timestamp,
          description
        FROM `{self.PROJECT_ID}.{self.DATASET_ID}.{self.CONFIG_TABLE}`
        ORDER BY priority ASC, created_timestamp DESC
        """

        try:
            results = self.client.query(query).result()
            datasets = [dict(row) for row in results]
            return datasets
        except GoogleCloudError as e:
            logger.error(f"Failed to list datasets: {e}")
            return []

    def unregister_dataset(self, config_id: str) -> bool:
        """Unregister (disable) a dataset"""
        query = f"""
        UPDATE `{self.PROJECT_ID}.{self.DATASET_ID}.{self.CONFIG_TABLE}`
        SET enabled = FALSE
        WHERE config_id = '{config_id}'
        """

        try:
            self.client.query(query).result()
            logger.info(f"✓ Disabled dataset: {config_id}")
            return True
        except GoogleCloudError as e:
            logger.error(f"Failed to disable dataset: {e}")
            return False

    def update_priority(self, config_id: str, priority: int) -> bool:
        """Update processing priority for a dataset"""
        query = f"""
        UPDATE `{self.PROJECT_ID}.{self.DATASET_ID}.{self.CONFIG_TABLE}`
        SET priority = {priority}
        WHERE config_id = '{config_id}'
        """

        try:
            self.client.query(query).result()
            logger.info(f"✓ Updated priority for {config_id} to {priority}")
            return True
        except GoogleCloudError as e:
            logger.error(f"Failed to update priority: {e}")
            return False


def main():
    """Entry point"""
    parser = argparse.ArgumentParser(
        description='Register datasets in the pipeline configuration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Register a new dataset
  python register_dataset.py --dataset DurangoPD --table November2025

  # Register with custom priority
  python register_dataset.py --dataset TelluridePD --table October2025 --priority 5

  # List all configured datasets
  python register_dataset.py --list

  # Disable a dataset
  python register_dataset.py --unregister durango-november-2025

  # Update priority
  python register_dataset.py --update-priority durango-november-2025 10
        """
    )

    group = parser.add_mutually_exclusive_group(required=True)

    group.add_argument(
        '--dataset',
        help='Dataset name (e.g., DurangoPD, TelluridePD)'
    )

    group.add_argument(
        '--list',
        action='store_true',
        help='List all configured datasets'
    )

    group.add_argument(
        '--unregister',
        metavar='CONFIG_ID',
        help='Disable a dataset by config_id'
    )

    group.add_argument(
        '--update-priority',
        nargs=2,
        metavar=('CONFIG_ID', 'PRIORITY'),
        help='Update priority for a dataset'
    )

    parser.add_argument(
        '--table',
        help='Table name (e.g., November2025)'
    )

    parser.add_argument(
        '--priority',
        type=int,
        default=100,
        help='Processing priority (lower = processed first, default: 100)'
    )

    parser.add_argument(
        '--owner',
        default='colin',
        help='Dataset owner (default: colin)'
    )

    parser.add_argument(
        '--disable',
        action='store_true',
        help='Register dataset as disabled'
    )

    args = parser.parse_args()

    registry = DatasetRegistry()

    # Handle list command
    if args.list:
        datasets = registry.list_datasets()
        if not datasets:
            print("No datasets configured")
            return

        print("\n" + "=" * 120)
        print("CONFIGURED DATASETS")
        print("=" * 120)
        print(
            f"{'Config ID':<35} {'Dataset':<20} {'Table':<20} "
            f"{'Priority':<8} {'Enabled':<8} {'Last Processed':<20}"
        )
        print("-" * 120)

        for ds in datasets:
            last_processed = (
                ds['last_processed_timestamp'].strftime('%Y-%m-%d %H:%M:%S')
                if ds['last_processed_timestamp'] else 'Never'
            )
            print(
                f"{ds['config_id']:<35} {ds['dataset_name']:<20} "
                f"{ds['source_table_name']:<20} {ds['priority']:<8} "
                f"{str(ds['enabled']):<8} {last_processed:<20}"
            )

        print("=" * 120 + "\n")
        return

    # Handle unregister command
    if args.unregister:
        registry.unregister_dataset(args.unregister)
        return

    # Handle update priority command
    if args.update_priority:
        config_id, priority = args.update_priority
        registry.update_priority(config_id, int(priority))
        return

    # Handle register command
    if args.dataset and args.table:
        registry.register_dataset(
            dataset_name=args.dataset,
            table_name=args.table,
            priority=args.priority,
            owner=args.owner,
            enabled=not args.disable
        )
        return

    # If dataset is provided but not table
    if args.dataset:
        parser.error("--table is required with --dataset")


if __name__ == '__main__':
    main()
