"""
Utility functions for pipeline orchestration.

Provides common functionality for BigQuery operations, logging, and configuration.
"""

import logging
from typing import Optional, Dict, Any
from datetime import datetime

from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError


# Configure logging
def setup_logging(log_level: str = 'INFO', log_file: Optional[str] = None) -> logging.Logger:
    """
    Configure logging for pipeline operations.

    Args:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional file path for log output

    Returns:
        Configured logger instance
    """
    logger = logging.getLogger('pipeline')
    logger.setLevel(getattr(logging, log_level))

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(getattr(logging, log_level))
    console_format = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    console_handler.setFormatter(console_format)
    logger.addHandler(console_handler)

    # File handler (if specified)
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(getattr(logging, log_level))
        file_format = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        file_handler.setFormatter(file_format)
        logger.addHandler(file_handler)

    return logger


class BigQueryClient:
    """Wrapper around Google Cloud BigQuery client with common operations."""

    def __init__(self, project_id: str, location: str = 'US'):
        """
        Initialize BigQuery client.

        Args:
            project_id: GCP project ID
            location: BigQuery dataset location (default: US)
        """
        self.project_id = project_id
        self.location = location
        self.client = bigquery.Client(project=project_id, location=location)

    def execute_query(self, query: str, timeout: int = 3600) -> bigquery.QueryJob:
        """
        Execute a SQL query.

        Args:
            query: SQL query string
            timeout: Query timeout in seconds

        Returns:
            Query job result
        """
        job_config = bigquery.QueryJobConfig(
            maximum_bytes_billed=10 * 1024 * 1024 * 1024,  # 10 GB max
            timeout_ms=timeout * 1000
        )
        return self.client.query(query, job_config=job_config)

    def execute_procedure(self, procedure_name: str, *args) -> None:
        """
        Execute a stored procedure.

        Args:
            procedure_name: Full procedure name (project.dataset.procedure)
            *args: Procedure arguments

        Raises:
            GoogleCloudError: If procedure execution fails
        """
        arg_str = ', '.join(f"'{arg}'" for arg in args)
        query = f"CALL `{procedure_name}`({arg_str})"
        self.execute_query(query).result()

    def table_exists(self, table_id: str) -> bool:
        """
        Check if a table exists.

        Args:
            table_id: Full table ID (project.dataset.table)

        Returns:
            True if table exists, False otherwise
        """
        try:
            self.client.get_table(table_id)
            return True
        except GoogleCloudError:
            return False

    def get_table_row_count(self, table_id: str) -> int:
        """
        Get row count for a table.

        Args:
            table_id: Full table ID (project.dataset.table)

        Returns:
            Number of rows in table
        """
        query = f"SELECT COUNT(*) as count FROM `{table_id}`"
        result = self.execute_query(query).result()
        return list(result)[0]['count']

    def get_dataset_config(self, project_id: str, dataset_id: str) -> Dict[str, Any]:
        """
        Fetch all dataset configurations.

        Args:
            project_id: GCP project ID
            dataset_id: BigQuery dataset ID

        Returns:
            List of configuration records
        """
        query = f"""
        SELECT *
        FROM `{project_id}.{dataset_id}.dataset_pipeline_config`
        WHERE enabled = TRUE
        ORDER BY priority ASC
        """
        result = self.execute_query(query).result()
        return [dict(row) for row in result]

    def get_processing_stats(self, project_id: str, dataset_id: str, days: int = 7) -> Dict[str, Any]:
        """
        Get processing statistics for the last N days.

        Args:
            project_id: GCP project ID
            dataset_id: BigQuery dataset ID
            days: Number of days to look back

        Returns:
            Processing statistics dictionary
        """
        query = f"""
        SELECT
          COUNT(*) as total_runs,
          COUNTIF(processing_status = 'SUCCESS') as successful,
          COUNTIF(processing_status = 'ERROR') as failed,
          SUM(total_rows) as total_rows_processed,
          SUM(new_reasons_classified) as new_classifications,
          ROUND(SUM(classification_cost_usd), 4) as total_cost
        FROM `{project_id}.{dataset_id}.dataset_processing_log`
        WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL {days} DAY)
        """
        result = self.execute_query(query).result()
        stats = list(result)[0]
        return dict(stats)


class PipelineConfig:
    """Manages pipeline configuration."""

    def __init__(self, project_id: str = 'durango-deflock', dataset_id: str = 'FlockML'):
        """
        Initialize pipeline configuration.

        Args:
            project_id: GCP project ID
            dataset_id: BigQuery dataset ID
        """
        self.project_id = project_id
        self.dataset_id = dataset_id
        self.bq = BigQueryClient(project_id)

    def get_enabled_datasets(self) -> list:
        """Get all enabled datasets from configuration."""
        query = f"""
        SELECT config_id, dataset_name, source_table_name, priority, owner
        FROM `{self.project_id}.{self.dataset_id}.dataset_pipeline_config`
        WHERE enabled = TRUE
        ORDER BY priority ASC
        """
        result = self.bq.execute_query(query).result()
        return [dict(row) for row in result]

    def register_dataset(self, dataset_name: str, table_name: str,
                        priority: int = 100, owner: str = 'colin') -> str:
        """Register a new dataset."""
        config_id = f"{dataset_name.lower()}-{table_name.lower()}".replace(' ', '-')

        query = f"""
        INSERT INTO `{self.project_id}.{self.dataset_id}.dataset_pipeline_config`
        (config_id, dataset_project, dataset_name, source_table_name,
         enabled, priority, output_dataset_name, output_suffix,
         description, owner, created_timestamp)
        VALUES (
          '{config_id}',
          '{self.project_id}',
          '{dataset_name}',
          '{table_name}',
          TRUE,
          {priority},
          NULL,
          '_classified',
          '{dataset_name} {table_name} dataset',
          '{owner}',
          CURRENT_TIMESTAMP()
        )
        """
        self.bq.execute_query(query).result()
        return config_id

    def disable_dataset(self, config_id: str) -> None:
        """Disable a dataset."""
        query = f"""
        UPDATE `{self.project_id}.{self.dataset_id}.dataset_pipeline_config`
        SET enabled = FALSE
        WHERE config_id = '{config_id}'
        """
        self.bq.execute_query(query).result()

    def get_processing_history(self, limit: int = 20) -> list:
        """Get recent processing history."""
        query = f"""
        SELECT
          config_id,
          execution_timestamp,
          processing_status,
          total_rows,
          new_reasons_classified,
          classification_cost_usd,
          TIMESTAMP_DIFF(completion_timestamp, execution_timestamp, SECOND) as duration_seconds
        FROM `{self.project_id}.{self.dataset_id}.dataset_processing_log`
        ORDER BY execution_timestamp DESC
        LIMIT {limit}
        """
        result = self.bq.execute_query(query).result()
        return [dict(row) for row in result]


def format_timestamp(ts) -> str:
    """Format timestamp for display."""
    if isinstance(ts, str):
        return ts
    return ts.strftime('%Y-%m-%d %H:%M:%S') if ts else 'Never'


def format_currency(amount: float) -> str:
    """Format amount as currency."""
    return f"${amount:.4f}"


def format_duration(seconds: int) -> str:
    """Format duration in human-readable format."""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        return f"{seconds // 60}m {seconds % 60}s"
    else:
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        return f"{hours}h {minutes}m"
