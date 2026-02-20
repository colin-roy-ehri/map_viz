-- Phase 1.1: Create Vertex AI Connection for Gemini Access
-- This connection enables BigQuery to call Gemini APIs through Vertex AI

-- Create connection to Vertex AI for Gemini access using the command line tool
```
bq mk --connection --location=us-central1 --project_id=durango-deflock \
  --connection_type=CLOUD_RESOURCE vertex-ai-connection
```

-- After running this script, you must:
-- 1. Copy the service account email from the connection details in BigQuery console
-- 2. Go to GCP Console → IAM & Admin → IAM
-- 3. Grant the service account "Vertex AI User" role

