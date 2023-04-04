import os
import csv
from neo4j import GraphDatabase
from dotenv import load_dotenv

load_dotenv()


# Pull env vars for auth and create neo4j driver
NEO4J_AUTH = (os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASS"))
NEO4J_URI = os.getenv("NEO4J_URI")
NEO4J_DRIVER = GraphDatabase.driver(NEO4J_URI, auth=NEO4J_AUTH)
SESSION = NEO4J_DRIVER.session()

from neo4j import GraphDatabase

# Define Cypher queries to create nodes and relationships
create_policy_node_query = """
MERGE (p:Policy {uq_id: $uq_id})
SET p.start_date = $start_date,
    p.issue_date = $issue_date,
    p.end_date = $end_date
"""

create_target_node_query = "MERGE (t:Target {name: $name})"
# create_cooccurrence_relationship_query = """
# MATCH (p:Policy {uq_id: $uq_id}), 
#       (t:Target {name: $name}) 
# CREATE (p)-[:COOCCURS_WITH]->(t)
# """

# Define function to create nodes and relationships for each row in the CSV file
def create_nodes_and_relationships(tx, row):
    # Extract relevant fields from row
    uq_id = row["Unique ID"]
    # category = row["Policy category"]
    # subcategory = row["Policy subcategory"]
    # direction = row["Policy relaxing or restricting"]
    start_date = row["Effective start date"]
    issue_date = row["Issued date"]
    end_date = row["Actual end date"]
    # auth_country = row["Country"]
    # auth_state = row["State"]
    targets = eval(row["Policy target"])

    # Create Policy node
    tx.run(create_policy_node_query, 
            uq_id=uq_id, 
            start_date=start_date, 
            issue_date=issue_date, 
            end_date=end_date)

    for i in range(len(targets)):
        target = str(targets[i])
        tx.run(create_target_node_query, name=target)


# Open CSV file and create nodes and relationships for each row
with open("processed/airtable_cleaned_033123.csv") as csvfile:
    reader = csv.DictReader(csvfile)
    with NEO4J_DRIVER.session() as session:
        for row in reader:
            session.write_transaction(create_nodes_and_relationships, row)

# Close connection to Neo4j
NEO4J_DRIVER.close()
