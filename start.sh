#!/bin/bash

students_dir="./students"

# Create necessary folders
mkdir -p images students floppy


# Check if /usr/lib/grub/i386-pc exists (basically check if Grub is installed)
if [ ! -d "/usr/lib/grub/i386-pc" ]; then
  echo "Grub is not installed. Please install Grub before running this script."
  exit 1
fi


# Download students forks
python3 download_forks.py

find_sourcefolder()
{
  local base_dir="$1"
  find "$base_dir" -type f -name 'CMakeLists.txt' | grep -v '/group_name/' | while read -r source_folder_path; do
    folder_path=$(dirname "$source_folder_path")
    echo "$folder_path"
  done
}

find_buildfolder()
{
  local base_dir="$1"
  local source_folder="$2"
  local build_base_dir="${base_dir}/build"
  local source_folder_name=$(basename "$source_folder")
  find "$build_base_dir" -type d -name "$source_folder_name" | while read -r build_folder_path; do
    echo $build_folder_path
  done
}

for student_folder in "$students_dir"/*; do
  if [ -d "$student_folder" ]; then
    echo "Processing student folder: $student_folder"
    source_folder=$(find_sourcefolder "$student_folder")
    build_folder=$(find_buildfolder "$student_folder" "$source_folder")

    if [ -z "$source_folder" ]; then
      echo "No source folder found in $student_folder"
      continue
    fi

    if [ -z "$build_folder" ]; then
      echo "No build folder found in $student_folder"
      continue
    fi

    echo "Source folder found: $source_folder"
    echo "Build folder found: $build_folder"

    # Extract group name
    group_name=$(basename "$source_folder")

    echo "Group is: $group_name"
    echo "Purging group build folder"

    # Change _start entry
    start_offset=1 # in megabytes
    echo "Updating start entry to ${start_offset}M"

    # Replace ". = 1M;" with ". = ${start_offset}M;" in linker.ld
    #sed -i "s/\. = [0-9]*M;/\. = ${start_offset}M;/g" $source_folder/src/arch/i386/linker.ld

    echo "Building Docker image"

    #IMAGE_ID=$(docker build --build-arg GRPNAME=$group_name --build-arg STUDENTFOLDER=$base_dir -f Dockerfile . -q)
    IMAGE_ID=$(docker build -f Dockerfile . -q)

    echo "Image ID: $IMAGE_ID"

    echo "Running build of OS for group $group_name"
    CONTAINER_ID=$(docker run -d -v $source_folder:/src -v $build_folder:/build $IMAGE_ID)

    if [ -f "$build_folder/kernel.bin" ]; then
      \mv "$build_folder/kernel.bin" "$build_folder/$group_name.bin"
      echo "Copying group_name.bin to ./images"
      cp "$build_folder/$group_name.bin" ./images
    fi


    echo "Stopping container"
    docker stop $CONTAINER_ID

    echo "Deleting container"
    docker rm $CONTAINER_ID
  else
    echo "$student_folder is not a directory"
  fi
done


# Compress kernel images
echo "Compressing kernel images"
for kernel_file in ./images/*.bin; do
  if [ -f "$kernel_file" ]; then
    xz -k -f -9 "$kernel_file"
  fi
done


# Create memdisk image of 1MB
echo "Creating memdisk image"
dd if=/dev/zero of=./floppy/memdisk.img bs=512 count=2458


# Mount memdisk image (requires sudo)
echo "Mounting memdisk image"
mkdir memdisk-mount
mformat -i memdisk.img
sudo mount -o loop ./floppy/memdisk.img memdisk-mount