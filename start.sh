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

echo "Pulling Docker image"
docker pull ghcr.io/ddybing/floppify:latest

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
      echo ""
      continue
    fi

    if [ -z "$build_folder" ]; then
      echo "No build folder found in $student_folder"
      echo ""
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

    #echo "Building Docker image"

    #IMAGE_ID=$(docker build -f Dockerfile . -q)

    #echo "Image ID: $IMAGE_ID"


    echo "Running build of OS for group $group_name"
    CONTAINER_ID=$(docker run -d -v $source_folder:/src -v $build_folder:/build ghcr.io/ddybing/floppify:latest)

    if [ -f "$build_folder/kernel.bin" ]; then
      \mv -f "$build_folder/kernel.bin" "$build_folder/$group_name.bin"
      echo "Copying group_name.bin to ./images"
      cp "$build_folder/$group_name.bin" ./images
    fi


    echo "Stopping container"
    docker stop $CONTAINER_ID

    echo "Deleting container"
    docker rm $CONTAINER_ID
    echo ""
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


# Create memdisk image of 2458 sectors (approx 1.2MiB)
echo "Creating and formatting memdisk image"
dd if=/dev/zero of=./floppy/memdisk.img bs=512 count=2000
mkfs.vfat ./floppy/memdisk.img


# Mount memdisk image (requires sudo)
echo "Mounting memdisk image"
mkdir -p memdisk-mount
sudo mount -o loop ./floppy/memdisk.img memdisk-mount

sudo mkdir -p memdisk-mount/boot/grub
sudo mkdir -p memdisk-mount/kernels

# Copy kernels
echo "Copying student kernels"
#sudo cp ./images/*.bin.xz memdisk-mount/kernels
#max=13
#count=0
#for kernel_file in ./images/*.bin.xz; do
#  if [ -f "$kernel_file" ]; then
#    base_name=$(basename "$kernel_file" .bin.xz)
#    sudo cp "$kernel_file" "memdisk-mount/kernels/$base_name.bin.xz"
#    count=$((count+1))
#    if [ $count -eq $max ]; then
#      break
#    fi
#  fi
#done

# Copy required modules to memdisk
echo "Copying GRUB files"
sudo cp /usr/lib/grub/i386-pc/{biosdisk,configfile,ext2,fat,gzio,ls,memdisk,multiboot,multiboot2,normal,part_gpt,part_msdos,xzio}.mod memdisk-mount/boot/grub/

# Generate grub config


sudo cp grub.cfg memdisk-mount/boot/grub/grub.cfg


# Unmount memdisk mount
sudo umount memdisk-mount

# Create GRUB image
grub-mkimage -C auto -p /boot/grub -O i386-pc -c grub.cfg -o ./floppy/grub.img ext2 part_gpt gzio xzio multiboot2 multiboot part_msdos biosdisk normal ls configfile fat memdisk -m ./floppy/memdisk.img -v

# Write images to floppy image
dd if=/usr/lib/grub/i386-pc/boot.img of=./floppy/floppy.img bs=512 count=1 conv=notrunc
dd if=./floppy/grub.img of=./floppy/floppy.img bs=512 seek=1 conv=notrunc

# Write custom partition table to image


echo ""
echo ""
echo "DONE!"