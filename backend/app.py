from fastapi import FastAPI, UploadFile, Form, HTTPException
from fastapi.responses import StreamingResponse
from PIL import Image
import fitz, qrcode
from io import BytesIO
from datetime import datetime
import tempfile
import os

fastapi_app = FastAPI()


# ===============================
# Fungsi buat QR Code
# ===============================
def generate_qr(data):
    qr = qrcode.QRCode(version=1, box_size=10, border=2)
    qr.add_data(data)
    qr.make(fit=True)
    return qr.make_image(fill_color="black", back_color="white").convert("RGB")


# ===============================
# Fungsi convert gambar → PDF
# ===============================
def image_to_pdf_bytes(image_bytes: bytes) -> bytes:
    img = Image.open(BytesIO(image_bytes))
    rgb_img = img.convert("RGB")

    buf = BytesIO()
    rgb_img.save(buf, format="PDF")
    buf.seek(0)
    return buf.getvalue()


# ===============================
# Fungsi tambah watermark
# ===============================
def add_watermarks(pdf_bytes, qr_img_pil, text):
    try:
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    except Exception:
        raise HTTPException(status_code=400, detail="File bukan PDF yang valid")

    # ubah QR PIL → bytes PNG
    qr_io = BytesIO()
    qr_img_pil.save(qr_io, format="PNG")
    qr_bytes = qr_io.getvalue()

    for page in doc:
        rect = page.rect
        # Tambah QR di pojok kiri atas
        qr_rect = fitz.Rect(20, 20, 120, 120)
        page.insert_image(qr_rect, stream=qr_bytes)

        # Tambah watermark text berulang
        for x in range(0, int(rect.width), 300):
            for y in range(0, int(rect.height), 150):
                page.insert_textbox(
                    fitz.Rect(x, y, x + 500, y + 50),
                    text,
                    fontname="helv",
                    fontsize=8,
                    color=(0.5, 0.5, 0.5),
                    overlay=True,
                )

    output = BytesIO()
    doc.save(output)
    doc.close()
    output.seek(0)
    return output


# ===============================
# Endpoint utama
# ===============================
@fastapi_app.post("/process")
async def process_file(
    file: UploadFile,
    using_for: str = Form(...),
    nama: str = Form(...),
    nisn: str = Form(...),
):
    contents = await file.read()
    filename = file.filename

    # Buat QR text
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    qr_data = f"{using_for} | {nama} | NISN: {nisn} | Generated {now_str}"
    qr_img = generate_qr(qr_data)

    # Kalau gambar → convert ke PDF
    if filename.lower().endswith((".jpg", ".jpeg", ".png")):
        pdf_bytes = image_to_pdf_bytes(contents)
    elif filename.lower().endswith(".pdf"):
        pdf_bytes = contents
    else:
        raise HTTPException(status_code=400, detail="Format file tidak didukung. Gunakan PDF atau gambar.")

    # Tambah watermark
    processed_pdf = add_watermarks(pdf_bytes, qr_img, qr_data)

    # Return file PDF hasil
    return StreamingResponse(
        processed_pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=watermarked.pdf"},
    )
    