-- Phase 1.2: Create Project Structure
-- Create datasets for ML models, classified outputs, and audit logging

-- Create dataset for ML models and UDFs
CREATE SCHEMA IF NOT EXISTS `durango-deflock.FlockML`
OPTIONS(
  description="BigQuery ML models and functions for Flock search classification",
  location="us-central1"
);

-- Create dataset for classified outputs
CREATE SCHEMA IF NOT EXISTS `durango-deflock.DurangoPD`
OPTIONS(
  description="Classified search records from DurangoPD dataset",
  location="us-central1"
);
