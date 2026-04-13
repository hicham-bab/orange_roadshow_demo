"""
Fretwork Guitars — Cortex Analyst Chat App
===========================================
Streamlit in Snowflake (SiS) app for the "dbt is essential in an AI world" demo.

Toggle between:
  - "Raw Data" mode  → queries raw Fivetran tables (Act 1: chaos)
  - "dbt Marts" mode → queries governed dbt marts (Act 3: trust)

Deploy as a Streamlit in Snowflake app. See streamlit/setup_sis_app.sql.
"""

import streamlit as st
import pandas as pd
import json
import requests
from snowflake.snowpark.context import get_active_session

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SEMANTIC_VIEWS = {
    "Raw Data (Fivetran)": {
        "view": "HICHAMB_FIVETRAN_DEMO.RETAIL_DEMO_RETAIL.cortex_retail_raw_sv",
        "label": "Raw Retail Data",
        "description": "Querying **raw Fivetran tables** directly. No transformations, no business logic.",
        "badge_color": "#FF4B4B",
        "badge_text": "RAW DATA",
        "warning": "This data is ungoverned. Answers may be inconsistent or incorrect.",
    },
    "dbt Marts (Governed)": {
        "view": "HICHAMB_FIVETRAN_DEMO.MARTS.cortex_retail_dbt_sv",
        "label": "dbt-Governed Marts",
        "description": "Querying **dbt-governed mart tables**. Tested, documented, with clear metric definitions.",
        "badge_color": "#00A86B",
        "badge_text": "dbt GOVERNED",
        "warning": None,
    },
}

DEMO_QUESTIONS = [
    "What was our total revenue last month?",
    "How many customers do we have by loyalty tier?",
    "Which region has the most orders?",
    "What is our average order value?",
    "Show me monthly B2C revenue for the last 6 months",
    "Which B2B accounts are at risk?",
    "What is our B2B cancellation rate?",
]

# ---------------------------------------------------------------------------
# Page setup
# ---------------------------------------------------------------------------

st.set_page_config(
    page_title="Fretwork Guitars — AI Analytics",
    page_icon="🎸",
    layout="wide",
)

st.title("Retail Demo — AI Analytics")
st.caption("Powered by Snowflake Cortex Analyst | A dbt + Snowflake + Fivetran demo")

# ---------------------------------------------------------------------------
# Sidebar: mode selector
# ---------------------------------------------------------------------------

with st.sidebar:
    st.header("Data Mode")
    mode = st.radio(
        "Select data source:",
        options=list(SEMANTIC_VIEWS.keys()),
        help="Switch between raw Fivetran data and dbt-governed marts to see the difference.",
    )

    config = SEMANTIC_VIEWS[mode]

    st.markdown(
        f"""
        <div style="background-color:{config['badge_color']}; padding:6px 12px;
                    border-radius:4px; text-align:center; color:white; font-weight:bold;
                    font-size:0.85rem; margin-bottom:8px;">
            {config['badge_text']}
        </div>
        """,
        unsafe_allow_html=True,
    )

    st.markdown(config["description"])

    if config["warning"]:
        st.warning(config["warning"])

    st.divider()
    st.subheader("Try asking:")
    for q in DEMO_QUESTIONS:
        if st.button(q, key=f"btn_{q[:20]}", use_container_width=True):
            st.session_state["prefill_question"] = q

    st.divider()
    st.caption(
        "**How this works:** Cortex Analyst generates SQL against the selected semantic view. "
        "The quality of the answers depends entirely on the quality of the underlying data definitions."
    )

# ---------------------------------------------------------------------------
# Chat history state
# ---------------------------------------------------------------------------

if "messages" not in st.session_state:
    st.session_state.messages = []

if "last_mode" not in st.session_state:
    st.session_state.last_mode = mode

# Clear chat on mode switch to avoid confusion
if st.session_state.last_mode != mode:
    st.session_state.messages = []
    st.session_state.last_mode = mode
    st.rerun()

# ---------------------------------------------------------------------------
# Display chat history
# ---------------------------------------------------------------------------

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        if message.get("sql"):
            with st.expander("Generated SQL", expanded=False):
                st.code(message["sql"], language="sql")
        if message.get("results") is not None:
            try:
                df = pd.DataFrame(message["results"])
                st.dataframe(df, use_container_width=True)
            except Exception:
                pass

# ---------------------------------------------------------------------------
# Cortex Analyst API call
# ---------------------------------------------------------------------------

def call_cortex_analyst(question: str, semantic_view: str) -> dict:
    """Call Cortex Analyst REST API via the active Snowpark session."""
    session = get_active_session()

    # Build request payload
    payload = {
        "messages": [{"role": "user", "content": [{"type": "text", "text": question}]}],
        "semantic_model_file": semantic_view,
    }

    # Use the session's REST API endpoint
    host = session.get_current_account().replace("_", "-").lower() + ".snowflakecomputing.com"
    url  = f"https://{host}/api/v2/cortex/analyst/message"

    token = session.connection.rest.token
    headers = {
        "Authorization": f"Snowflake Token=\"{token}\"",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    response = requests.post(url, headers=headers, json=payload, timeout=60)
    response.raise_for_status()
    return response.json()


def execute_sql(sql: str) -> list[dict]:
    """Execute generated SQL and return results as a list of dicts."""
    session = get_active_session()
    df = session.sql(sql).to_pandas()
    return df.to_dict(orient="records")


# ---------------------------------------------------------------------------
# Chat input
# ---------------------------------------------------------------------------

prefill = st.session_state.pop("prefill_question", None)
user_input = st.chat_input(
    placeholder="Ask a question about Fretwork Guitars sales, customers, or products...",
    key="chat_input",
) or prefill

if user_input:
    # Add user message to history
    st.session_state.messages.append({"role": "user", "content": user_input})

    with st.chat_message("user"):
        st.markdown(user_input)

    with st.chat_message("assistant"):
        with st.spinner("Generating SQL with Cortex Analyst..."):
            try:
                result     = call_cortex_analyst(user_input, config["view"])
                analyst_msg = result.get("message", {})
                content    = analyst_msg.get("content", [])

                # Extract text and SQL from response
                response_text = ""
                generated_sql  = None
                query_results  = None

                for block in content:
                    if block.get("type") == "text":
                        response_text += block.get("text", "")
                    elif block.get("type") == "sql":
                        generated_sql = block.get("statement", "")

                if generated_sql:
                    with st.spinner("Executing query..."):
                        try:
                            query_results = execute_sql(generated_sql)
                        except Exception as e:
                            response_text += f"\n\n_Query execution error: {e}_"

                # Display response
                if response_text:
                    st.markdown(response_text)

                if generated_sql:
                    with st.expander("Generated SQL", expanded=True):
                        st.code(generated_sql, language="sql")

                if query_results is not None:
                    df = pd.DataFrame(query_results)
                    st.dataframe(df, use_container_width=True)
                    response_text += f"\n\n_({len(df)} rows returned)_"

                # Save to history
                st.session_state.messages.append({
                    "role":    "assistant",
                    "content": response_text,
                    "sql":     generated_sql,
                    "results": query_results,
                })

            except requests.HTTPError as e:
                error_msg = f"Cortex Analyst API error: {e.response.status_code} — {e.response.text}"
                st.error(error_msg)
                st.session_state.messages.append({"role": "assistant", "content": error_msg})
            except Exception as e:
                error_msg = f"Unexpected error: {str(e)}"
                st.error(error_msg)
                st.session_state.messages.append({"role": "assistant", "content": error_msg})
