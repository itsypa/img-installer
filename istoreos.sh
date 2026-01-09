#!/bin/bash
mkdir -p openwrt

# 使用当前仓库的GitHub Releases作为源
REPO="itsypa/img-installer"
TAG="iStoreOS-24.10.5"
FILE_NAME="istoreos-24.10.5.img.gz"
OUTPUT_PATH="openwrt/istoreos.img.gz"

# 尝试从GitHub API获取最新的发布信息，自动查找匹配的文件
# 首先尝试使用API获取最新的发布
LATEST_RELEASE=$(curl -s https://api.github.com/repos/${REPO}/releases/latest)

# 检查是否成功获取最新发布
if [[ $? -eq 0 ]]; then
  # 检查assets字段是否存在且不为null
  HAS_ASSETS=$(echo ${LATEST_RELEASE} | jq -r '.assets != null')
  if [[ "$HAS_ASSETS" == "true" ]]; then
    # 尝试查找匹配的文件，修复正则表达式转义问题
    DOWNLOAD_URL=$(echo ${LATEST_RELEASE} | jq -r '.assets[] | select(.name | test("istoreos.*\\.img\\.gz$")) | .browser_download_url' 2>/dev/null | head -1)
  fi
  
  # 如果没有找到匹配的文件，尝试使用指定的TAG
  if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "从最新发布中未找到匹配的iStoreOS镜像文件，尝试使用指定的TAG: ${TAG}"
    SPECIFIC_RELEASE=$(curl -s https://api.github.com/repos/${REPO}/releases/tags/${TAG})
    
    # 检查特定发布的assets字段是否存在且不为null
    HAS_SPECIFIC_ASSETS=$(echo ${SPECIFIC_RELEASE} | jq -r '.assets != null')
    if [[ "$HAS_SPECIFIC_ASSETS" == "true" ]]; then
      DOWNLOAD_URL=$(echo ${SPECIFIC_RELEASE} | jq -r '.assets[] | select(.name == "'"$FILE_NAME"'") | .browser_download_url' 2>/dev/null)
    else
      echo "指定的TAG ${TAG} 不存在或没有assets字段"
    fi
  fi
fi

# 如果API调用失败或未找到文件，使用本地构建模式作为备选
if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
  echo "从GitHub API未找到有效的下载链接，进入本地构建模式"
  echo "请确保在当前目录下存在istoreos.img.gz文件"
  
  # 检查本地是否存在镜像文件
  if [[ -f "istoreos.img.gz" ]]; then
    echo "找到本地镜像文件，使用本地文件进行构建"
    # 复制到指定目录
    cp istoreos.img.gz ${OUTPUT_PATH}
    # 跳过后续下载步骤，直接进入构建阶段
    SKIP_DOWNLOAD=true
  else
    echo "错误：未找到本地镜像文件 istoreos.img.gz"
    echo "请手动下载或放置镜像文件到当前目录"
    exit 1
  fi
fi

# 初始化SKIP_DOWNLOAD变量
SKIP_DOWNLOAD=${SKIP_DOWNLOAD:-false}

# 如果没有跳过下载，则执行下载操作
if [[ "$SKIP_DOWNLOAD" == "false" ]]; then
  if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    echo "错误：未找到有效的下载链接！"
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
  else
    echo "下载失败！HTTP请求可能失败或URL无效。"
    exit 1
  fi
fi

# 执行解压操作（无论是下载的还是本地的文件）
echo "正在解压为:istoreos.img"
gzip -d openwrt/istoreos.img.gz
if [[ $? -eq 0 ]]; then
  ls -lh openwrt/
  echo "准备合成 istoreos 安装器"
else
  echo "解压失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/openwrt/istoreos.img:/mnt/istoreos.img \
        debian:buster \
        /supportFiles/istoreos/build.sh
