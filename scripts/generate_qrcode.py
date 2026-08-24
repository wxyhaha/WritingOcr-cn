import sys
import os
import base64
import io

def generate_qr_base64(text: str) -> str:
    try:
        import qrcode
        qr = qrcode.QRCode(
            version=None,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=10,
            border=4,
        )
        qr.add_data(text)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode("ascii")
        return f"data:image/png;base64,{b64}"
    except Exception as e:
        sys.stderr.write(f"QR Generation error: {e}\n")
        return ""

if __name__ == "__main__":
    if len(sys.argv) > 1:
        text = sys.argv[1]
        print(generate_qr_base64(text))
    else:
        print("")
