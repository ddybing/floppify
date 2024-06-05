base_dir=${1:-"./student"}
source_base_dir="${base_dir}/src"
build_base_dir="${base_dir}/build"


source_folder=""
build_folder=""

find_sourcefolder()
{
  find "$base_dir" -type f -name 'CMakeLists.txt' | grep -v '/group_name/' | while read -r source_folder_path; do
    folder_path=$(dirname "$source_folder_path")
    echo "$folder_path"
  done
}

find_buildfolder()
{
  source_folder_name=$(basename "$source_folder")
  find "$build_base_dir" -type d -name "$source_folder_name" | while read -r build_folder_path; do
    echo $build_folder_path
  done
}

# Find folders
source_folder=$(find_sourcefolder)
build_folder=$(find_buildfolder)

if [ -z "$source_folder" ]; then
  echo "No group folders found"
  exit 1
fi

echo "Source folder found"
echo "Build folder found"


echo "Group folders found"


# Extract group name
group_name=$(basename "$source_folder")


echo "Group is: $group_name"
echo "Purging group build folder"

# Change _start entry
start_offset=2 # in megabytes
echo "Updating start entry to ${start_offset}M"

# Replace ". = 1M;" with ". = ${start_offset}M;" in linker.ld
sed -i "s/\. = [0-9]*M;/\. = ${start_offset}M;/g" $source_folder/src/arch/i386/linker.ld

echo "Building Docker image"

#IMAGE_ID=$(docker build --build-arg GRPNAME=$group_name --build-arg STUDENTFOLDER=$base_dir -f Dockerfile . -q)
IMAGE_ID=$(docker build -f Dockerfile . -q)

echo "Image ID: $IMAGE_ID"

echo "Running build of OS for group $group_name"
CONTAINER_ID=$(docker run -d -v $source_folder:/src -v $build_folder:/build $IMAGE_ID)

if [ -f "$build_folder/kernel.bin" ]; then
  mv "$build_folder/kernel.bin" "$build_folder/$group_name.bin"
fi

#docker cp $CONTAINER_ID:/build $base_dir

echo "Stopping container"
docker stop $CONTAINER_ID

echo "Deleting container"
docker rm $CONTAINER_ID
