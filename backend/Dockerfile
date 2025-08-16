# Gunakan image Python resmi sebagai base image
FROM python:3.9-slim

# Install system dependencies (OCR, poppler, zbar, dll) + set timezone
RUN apt-get update && apt-get install -y \
    tzdata \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-ind \
    libzbar0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
 && rm -rf /var/lib/apt/lists/*

# Set timezone ke Asia/Jakarta (UTC+7)
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set working directory di dalam container
WORKDIR /app

# Salin file requirement ke container
COPY requirements.txt .

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Salin semua file aplikasi
COPY . .

# Expose 2 port: 8501 (Streamlit) & 8000 (FastAPI)
EXPOSE 8501 8000

# Jalankan Streamlit & FastAPI secara paralel
CMD ["sh", "-c", "streamlit run app.py --server.port=8501 --server.address=0.0.0.0 & uvicorn app:fastapi_app --host 0.0.0.0 --port 8000"]
