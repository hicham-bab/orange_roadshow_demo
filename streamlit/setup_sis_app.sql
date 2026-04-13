-- =============================================================================
-- Create Streamlit in Snowflake App
-- Run as SYSADMIN or owner of the MARTS schema
-- =============================================================================

USE ROLE SYSADMIN;
USE DATABASE FRETWORK_GUITARS;
USE SCHEMA MARTS;
USE WAREHOUSE FRETWORK_WH;

-- 1. Create a stage to host the Streamlit app code
CREATE STAGE IF NOT EXISTS FRETWORK_GUITARS.MARTS.streamlit_stage
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Fretwork Guitars Streamlit app files';

-- 2. Upload app file from your local machine (run from repo root in Snowsql or SnowCLI):
--    PUT file://streamlit/cortex_analyst_chat.py @FRETWORK_GUITARS.MARTS.streamlit_stage auto_compress=false overwrite=true;

-- 3. Create the Streamlit app
CREATE OR REPLACE STREAMLIT FRETWORK_GUITARS.MARTS.fretwork_cortex_chat
    ROOT_LOCATION = '@FRETWORK_GUITARS.MARTS.streamlit_stage'
    MAIN_FILE = 'cortex_analyst_chat.py'
    QUERY_WAREHOUSE = FRETWORK_WH
    COMMENT = 'Fretwork Guitars Cortex Analyst chat app — dbt demo';

-- 4. Grant access to analysts
GRANT USAGE ON STREAMLIT FRETWORK_GUITARS.MARTS.fretwork_cortex_chat
    TO ROLE FRETWORK_ANALYST;

-- 5. View the app URL
SHOW STREAMLITS IN DATABASE FRETWORK_GUITARS;

-- =============================================================================
-- To open the app:
-- In Snowsight → Projects → Streamlit → fretwork_cortex_chat
-- Or use the URL from SHOW STREAMLITS output
-- =============================================================================
