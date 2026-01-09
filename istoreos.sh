#!/bin/bash
mkdir -p openwrt

# 使用当前仓库的GitHub Releases作为源
REPO="itsypa/img-installer"
TAG="iStoreOS-24.10.5"
FILE_NAME="istoreos-24.10.5.img.gz"
OUTPUT_PATH="openwrt/istoreos.img.gz"
# 当前仓库的GitHub Releases下载地址
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${FILE_NAME}"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME"
  exit 1
fi

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"

# 确保openwrt目录存在
mkdir -p openwrt

# 下载文件，添加--fail选项确保HTTP错误会导致curl退出
curl -L -f -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载istoreos成功!"
  
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
  
  echo "正在解压为:istoreos.img"
  gzip -d openwrt/istoreos.img.gz
  if [[ $? -eq 0 ]]; then
    ls -lh openwrt/
    echo "准备合成 istoreos 安装器"
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
        -v $(pwd)/openwrt/istoreos.img:/mnt/istoreos.img \
        debian:buster \
        /supportFiles/istoreos/build.sh
