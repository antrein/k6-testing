# Fixed configuration variables
CLUSTER_NAME="antrein"
ZONE="asia-southeast1-a"
PROJECT="antrein-ta"
KEY_FILE="gcp.json"

# Authenticate using the service account key file
gcloud auth activate-service-account --key-file=$KEY_FILE

# Set project and get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT

# Get cluster details
cluster_details=$(gcloud container clusters describe $CLUSTER_NAME --zone $ZONE --format="json" --project $PROJECT)

# Get the node pool name
node_pools=$(echo $cluster_details | jq -r '.nodePools[].name')

# Initialize totals
total_nodes=0
total_cpus=0
total_memory_gb=0

# Iterate through each node pool
for node_pool in $node_pools; do
  # Get the node details
  node_details=$(gcloud container node-pools describe $node_pool --cluster $CLUSTER_NAME --zone $ZONE --format="json" --project $PROJECT)
  
  # Calculate total number of nodes in the current pool
  num_nodes=$(echo $node_details | jq -r '.initialNodeCount')
  
  # Get the machine type
  machine_type=$(echo $node_details | jq -r '.config.machineType')
  
  # Get the machine type details
  machine_details=$(gcloud compute machine-types describe $machine_type --zone $ZONE --format="json" --project $PROJECT)
  
  # Calculate number of CPUs per node
  num_cpus_per_node=$(echo $machine_details | jq -r '.guestCpus')
  
  # Calculate memory in GB per node
  memory_mb_per_node=$(echo $machine_details | jq -r '.memoryMb')
  memory_gb_per_node=$((memory_mb_per_node / 1024))
  
  # Update totals
  total_nodes=$((total_nodes + num_nodes))
  total_cpus=$((total_cpus + (num_cpus_per_node * num_nodes)))
  total_memory_gb=$((total_memory_gb + (memory_gb_per_node * num_nodes)))
done

# Output the cluster specs
echo "$total_nodes $num_cpus_per_node $memory_gb_per_node"
