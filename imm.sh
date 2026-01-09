#!/bin/bash
mkdir -p imm
#https://github.com/wukongdaily/AutoBuildImmortalWrt/releases/download/Autobuild-x86-64/immortalwrt-24.10.0-x86-64-generic-squashfs-combined-efi.img.gz

REPO="wukongdaily/AutoBuildImmortalWrt"
TAG="img-installer"
# FILE_NAME="immortalwrt-24.10.2-x86-64-generic-squashfs-combined-efi.img.gz"
FILE_NAME="immortalwrt-24.10.4.img.gz"
OUTPUT_PATH="imm/immortalwrt.img.gz"

# DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPO/releases/tags/$TAG | jq -r '.assets[] | select(.name == "'"$FILE_NAME"'") | .browser_download_url')
DOWNLOAD_URL="https://github.com/itsypa/img-installer/releases/download/immortalwrt-24.10.4/immortalwrt-24.10.4.img.gz"
# 此处可以替换op固件下载地址,但必须是 直链才可以,网盘那种地址是不行滴。举3个例子
# 原版OpenWrt
# DOWNLOAD_URL="https://downloads.openwrt.org/releases/24.10.3/targets/x86/64/openwrt-24.10.3-x86-64-generic-squashfs-combined-efi.img.gz"
# 原版immortalwrt
# DOWNLOAD_URL="https://downloads.immortalwrt.org/releases/24.10.3/targets/x86/64/immortalwrt-24.10.3-x86-64-generic-squashfs-combined-efi.img.gz"
# 原版KWRT
# DOWNLOAD_URL="https://dl.openwrt.ai/releases/24.10/targets/x86/64/kwrt-03.08.2025-x86-64-generic-squashfs-combined-efi.img.gz"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME"
  exit 1
fi

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"

# 确保imm目录存在
mkdir -p imm

# 下载文件，添加--fail选项确保HTTP错误会导致curl退出
curl -L -f -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载immortalwrt-24.10.3成功!"
  
  # 检查文件大小，确保不是空文件
  file_size=$(wc -c < "$OUTPUT_PATH")
  if [[ $file_size -eq 0 ]]; then
    echo "错误：下载的文件为空！"
    exit 1
  fi
  
  echo "文件大小: $file_size 字节"
  
  # 使用file命令检查文件类型
  file_type=$(file -b "$OUTPUT_PATH")
  echo "文件类型: $file_type"
  
  # 检查文件是否为gzip格式
  if [[ "$file_type" != *"gzip compressed data"* ]]; then
    echo "错误：下载的文件不是有效的gzip格式！"
    # 查看文件前100个字节，帮助调试
    echo "文件前100字节内容:"
    head -c 100 "$OUTPUT_PATH" | xxd
    exit 1
  fi
  
  echo "正在解压为:immortalwrt.img"
  gzip -d imm/immortalwrt.img.gz
  if [[ $? -eq 0 ]]; then
    ls -lh imm/
    echo "准备合成 immortalwrt 安装器"
  else
    echo "解压失败！"
    exit 1
  fi
else
  echo "下载失败！HTTP请求可能失败或URL无效。"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/imm/immortalwrt.img:/mnt/immortalwrt.img \
        debian:buster \
        /supportFiles/immortalwrt/build.sh
