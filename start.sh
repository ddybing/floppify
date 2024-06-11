#!/bin/bash

students_dir="./students"

# Create necessary folders
mkdir -p images students floppy

# Set Grub and kernel variables
directory="./images"

# Output GRUB configuration file
grub_cfg="grub.cfg"


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


# Create memdisk image
echo "Creating and formatting memdisk image"
dd if=/dev/zero of=./floppy/memdisk.img bs=512 count=800
mkfs.vfat ./floppy/memdisk.img


# Mount memdisk image (requires sudo)
echo "Mounting memdisk image"
mkdir -p memdisk-mount
sudo mount -o loop ./floppy/memdisk.img memdisk-mount

sudo mkdir -p memdisk-mount/boot/grub

# Copy required modules to memdisk
echo "Copying GRUB files"
sudo cp /usr/lib/grub/i386-pc/{biosdisk,configfile,ext2,fat,gzio,ls,memdisk,multiboot,multiboot2,normal,part_gpt,part_msdos,xzio}.mod memdisk-mount/boot/grub/



# Generate GRUB config
> grub.cfg
echo "insmod gzio" >> grub.cfg
echo "insmod xzio" >> grub.cfg
echo "insmod multiboot2" >> grub.cfg
echo "insmod multiboot" >> grub.cfg
echo "insmod part_msdos" >> grub.cfg
echo "insmod biosdisk" >> grub.cfg
echo "insmod normal" >> grub.cfg
echo "insmod ls" >> grub.cfg
echo "insmod configfile" >> grub.cfg
echo "insmod fat" >> grub.cfg
echo "insmod memdisk" >> grub.cfg
echo "insmod ext2" >> grub.cfg
echo "insmod part_gpt" >> grub.cfg

echo "set timeout=60" >> grub.cfg
echo "set default=0" >> grub.cfg
echo "set GRUB_TIMEOUT_STYLE=menu" >> grub.cfg

echo "set menu_title=\"IKT218 Boot Menu\"" >> grub.cfg

for file in "$directory"/*.bin.xz; do
  if [[ -f "$file" ]]; then
    filename=$(basename -- "$file")
    entry_name="Boot ${filename%.bin.xz}"

    cat <<EOL >> "$grub_cfg"
menuentry '$entry_name' {
    multiboot2 (fd0,msdos1)/kernels/$filename
    boot
}
EOL

  fi
done


sudo cp grub_minimal.cfg memdisk-mount/boot/grub/grub_minimal.cfg


# Unmount memdisk mount
sudo umount memdisk-mount

# Create GRUB image
grub-mkimage -C auto -O i386-pc -c grub_minimal.cfg -o ./floppy/grub.img ext2 part_gpt gzio xzio multiboot2 multiboot part_msdos biosdisk normal ls configfile fat memdisk -m ./floppy/memdisk.img -v

# Write images to floppy image
dd if=/dev/zero of=./floppy/floppy.img bs=512 count=2880
dd if=/usr/lib/grub/i386-pc/boot.img of=./floppy/floppy.img bs=512 count=1 conv=notrunc
dd if=./floppy/grub.img of=./floppy/floppy.img bs=512 seek=1 conv=notrunc

# Write custom partition table to image
dd if=./floppy/fat_table.bin of=./floppy/floppy.img bs=1 seek=446 count=64 conv=notrunc

# Losetup and format floppy image
sudo losetup --partscan /dev/loop9 ./floppy/floppy.img
sudo mkfs.vfat /dev/loop9p1

# Mount and copy kernels
mkdir -p ./floppy/kernelsmount
sudo mount /dev/loop9p1 ./floppy/kernelsmount
sudo mkdir -p ./floppy/kernelsmount/kernels
rm -rf ./images/*.bin
sudo cp ./images/*.bin.xz ./floppy/kernelsmount/kernels/
sudo cp grub.cfg ./floppy/kernelsmount/grub.cfg

sudo umount ./floppy/kernelsmount
sudo losetup -d /dev/loop9


echo ""
echo ""
echo "DONE!"