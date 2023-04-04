import os
import csv
from neo4j import GraphDatabase
from datetime import datetime

from loguru import logger
from dotenv import load_dotenv

load_dotenv()


# Pull env vars for auth and create neo4j driver
NEO4J_AUTH = (os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASS"))
NEO4J_URI = os.getenv("NEO4J_URI")
NEO4J_DRIVER = GraphDatabase.driver(NEO4J_URI, auth=NEO4J_AUTH)
SESSION = NEO4J_DRIVER.session()

# Define Cypher queries to create nodes and relationships
create_policy_node_query = """
MERGE (p:Policy {uq_id: $uq_id})
SET p.start_date = date($start_date),
    p.issue_date = date($issue_date),
    p.actual_end_date = date($actual_end_date),
    p.anticipated_end_date = date($anticipated_end_date)
"""

create_target_node_query = "MERGE (t:Target {name: $name})"
create_target_relationship_query = """
MATCH (p:Policy {uq_id: $uq_id}), 
      (t:Target {name: $name}) 
MERGE (p)-[:TARGETS]->(t)
"""

create_category_node_query = "MERGE (c:Category {category_name: $category_name})"
create_category_relationship_query = """
MATCH (p:Policy {uq_id: $uq_id}), 
      (c:Category {category_name: $category_name}) 
MERGE (c)-[:APPLIES]->(p)
"""
create_subcategory_node_query = "MERGE (s:Subcategory {subcat_name: $subcat_name})"
create_subcategory_relationship_query = """
MATCH (p:Policy {uq_id: $uq_id}), 
      (s:Subcategory {subcat_name: $subcat_name}) 
MERGE (s)-[:APPLIES]->(p)
"""
create_subcat_cat_relationship_query = """
MATCH (c:Category {category_name: $category_name}), 
      (s:Subcategory {subcat_name: $subcat_name}) 
MERGE (c)-[:INCLUDES]->(s)
"""

create_direction_node_query = "MERGE (d:Direction {name: $name})"
create_direction_relationship_query = """
MATCH (p:Policy {uq_id: $uq_id}), 
      (d:Direction {name: $name}) 
MERGE (p)-[:IS]->(d)
"""

create_country_node_query = "MERGE (c:Country:Geo {country_name: $country_name})"
create_country_relationship_query = """
MATCH (p:Policy {uq_id: $uq_id}), 
      (c:Country {country_name: $country_name}) 
MERGE (c)-[:AUTHORIZES]->(p)
"""

create_state_node_query = "MERGE (s:State:Geo {state_name: $state_name})"
create_state_relationship_query = """
MATCH (p:Policy {uq_id: $uq_id}), 
      (s:State {state_name: $state_name}) 
MERGE (s)-[:AUTHORIZES]->(p)
"""

create_geo_relationship_query = """
MATCH (c:Country {country_name: $country_name}), 
      (s:State {state_name: $state_name}) 
MERGE (c)-[:CONTAINS]->(s)
"""

category_dict = {
    'Adaptation and mitigation measures': 'Social distancing',
    'Event delays or cancellations': 'Social distancing',
    'Hazard pay': 'Enabling and relief measures',
    'Private sector closures': 'Social distancing',
    'School closures': 'Social distancing',
    'Public health emergency declaration': 'Emergency declarations',
    'Vaccine administration, distribution, and logistics': 'Vaccinations',
    'Mass gathering restrictions': 'Social distancing',
    'International travel restriction': 'Travel restrictions',
    'Support for telemedicine': 'Support for public health and clinical capacity',
    'Testing': 'Contact tracing/Testing',
    'Health screening': 'Social distancing',
    'Leave entitlement adjustments': 'Enabling and relief measures',
    'Medical licensing waivers': 'Support for public health and clinical capacity',
    'Quarantine': 'Social distancing',
    'Regulatory relief': 'Enabling and relief measures',
    'Enforcement': 'Authorization and enforcement',
    'Other measures to support public health and clinical capacity': 'Support for public health and clinical capacity',
    'Utility payment': 'Enabling and relief measures',
    'Relief funding': 'Enabling and relief measures',
    'Other relief measures': 'Enabling and relief measures',
    'Alternative election measures': 'Social distancing',
    'Authorization': 'Authorization and enforcement',
    'Face mask required': 'Face mask',
    'Isolation': 'Social distancing',
    'Face mask suggested': 'Face mask',
    'Distancing mandate': 'Social distancing',
    'Stay at home': 'Social distancing',
    'Visitor restrictions': 'Social distancing',
    'Safer at home': 'Social distancing',
    'Tax delay': 'Enabling and relief measures',
    'Public service closures': 'Social distancing',
    'Notification requirements': 'Support for public health and clinical capacity',
    'Emergency use or expanded market authorization': 'Support for public health and clinical capacity',
    'Other labor protections': 'Enabling and relief measures',
    'General emergency declaration': 'Emergency declarations',
    'Other forms of social distancing': 'Social distancing',
    'Anti-price gouging measures': 'Enabling and relief measures',
    'Modification of unemployment benefits': 'Enabling and relief measures',
    'Face mask exemption': 'Face mask',
    'Lockdown': 'Social distancing',
    'Remote Notarization': 'Enabling and relief measures',
    'Activation of military for logistical and/or medical support': 'Military mobilization',
    'Vaccine mandate': 'Vaccinations',
    'Support for essential workers': 'Enabling and relief measures',
    'Budget modifications': 'Enabling and relief measures',
    'Vaccine-related plan': 'Vaccinations',
    'Extension of public services': 'Enabling and relief measures',
    'Curfews': 'Social distancing',
    'Multi-vaccine policy': 'Vaccinations',
    'Vaccine cost, financing, and insurance': 'Vaccinations',
    'Domestic travel restrictions (interstate)': 'Travel restrictions',
    'Healthcare facility licensing waivers': 'Support for public health and clinical capacity',
    'Elective procedure delay or cancellation': 'Support for public health and clinical capacity',
    'Domestic travel restrictions (intrastate)':'Travel restrictions',
    'Risk Communication': 'Support for public health and clinical capacity',
    'Domestic travel restriction': 'Travel restrictions',
    'Contact tracing': 'Contact tracing/Testing',
    'Face mask (other)': 'Face mask',
    'Face covering': 'Social distancing',
    'Eviction and foreclosure delays': 'Enabling and relief measures',
    'Vaccine prioritization': 'Vaccinations',
    'Stimulus payments': 'Enabling and relief measures',
    'Crisis standards of care': 'Support for public health and clinical capacity',
    'Coverage for cost of testing': 'Support for public health and clinical capacity',
    'Prison population reduction': 'Social distancing',
    'Mortgage payment support': 'Enabling and relief measures',
    'Immunity for medical providers': 'Support for public health and clinical capacity',
    'Revised “emergency personnel” designations': 'Support for public health and clinical capacity',
    'Vaccine exemption or alternative':'Vaccinations',
    'Early prison release':'Enabling and relief measures'}

# Define function to create nodes and relationships for each row in the CSV file
def create_nodes_and_relationships(tx, row):
    # Extract relevant fields from row
    uq_id = row["Unique ID"]
    category = row["Policy category"]
    subcategory = row["Policy subcategory"]
    direction = row["Policy relaxing or restricting"]

    start_date_str = row["Effective start date"]
    issue_date_str = row["Issued date"]
    anticipated_end_date_str = row["Anticipated end date"]
    actual_end_date_str = row["Actual end date"]

    if start_date_str:
        start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
    else:
        start_date = None
    if issue_date_str:
        issue_date = datetime.strptime(issue_date_str, '%Y-%m-%d').date()
    else:
        issue_date = None
    if anticipated_end_date_str:
        anticipated_end_date = datetime.strptime(anticipated_end_date_str, '%Y-%m-%d').date()
    else:
        anticipated_end_date = None
    if actual_end_date_str:
        actual_end_date = datetime.strptime(actual_end_date_str, '%Y-%m-%d').date()
    else:
        actual_end_date = None

    auth_country = row["Country"]
    auth_state = row["State"]

    # Create Policy node
    tx.run(create_policy_node_query, 
            uq_id=uq_id, 
            start_date=start_date, 
            issue_date=issue_date, 
            anticipated_end_date = anticipated_end_date,
            actual_end_date=actual_end_date)

    if row["Policy target"]:
        targets = eval(row["Policy target"])
        for i in range(len(targets)):
            target = str(targets[i])
            tx.run(create_target_node_query, name=target)
            tx.run(create_target_relationship_query, uq_id=uq_id, name=target)
    
    if row["Policy category"]:
        category = str(category)
        tx.run(create_category_node_query, category_name=category)
        tx.run(create_category_relationship_query, uq_id=uq_id, category_name=category)
        if row["Policy subcategory"]:
            if subcategory in category_dict:
                category = category_dict[subcategory]
                tx.run(create_subcategory_node_query, subcat_name=subcategory)
                tx.run(create_subcategory_relationship_query, uq_id=uq_id, subcat_name=subcategory)
                tx.run(create_subcat_cat_relationship_query, subcat_name=subcategory, category_name=category)

    if row["Policy relaxing or restricting"]:
        direction = str(direction)
        tx.run(create_direction_node_query, name=direction)
        tx.run(create_direction_relationship_query, uq_id=uq_id, name=direction)


    if row["Country"]:
        country = str(auth_country)
        tx.run(create_country_node_query, country_name=country)
        if row["State"]:
            state = str(auth_state)
            tx.run(create_state_node_query, state_name=state)
            tx.run(create_state_relationship_query, uq_id=uq_id,state_name=state)
            tx.run(create_geo_relationship_query,country_name=country,state_name=state)
        else:
            tx.run(create_country_relationship_query, uq_id=uq_id, country_name=country)



# Open CSV file and create nodes and relationships for each row
with open("processed/airtable_cleaned_033123.csv") as csvfile:
    reader = csv.DictReader(csvfile)
    with NEO4J_DRIVER.session() as session:
        for row in reader:
            try:
                session.write_transaction(create_nodes_and_relationships, row)
            except Exception as e:
                logger.error(f"An exception occurred: {e}")
                raise


# Close connection to Neo4j
NEO4J_DRIVER.close()
