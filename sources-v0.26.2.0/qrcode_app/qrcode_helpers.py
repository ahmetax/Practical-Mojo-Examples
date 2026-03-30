"""
QR Code App Flask route handler helper.
Imported by qrcode_app.mojo via Python.import_module().
"""

import qrcode
import qrcode.constants
import base64
import io
from PIL import Image
from pyzbar.pyzbar import decode as pyzbar_decode
from flask import render_template, request, redirect, url_for, flash, send_file


# ------------------------------------------------------------------ #
# QR content builders
# ------------------------------------------------------------------ #
def build_vcard(first, last, phone, email, org, url):
    lines = [
        "BEGIN:VCARD",
        "VERSION:3.0",
        f"FN:{first} {last}".strip(),
        f"N:{last};{first};;;",
    ]
    if org:    lines.append(f"ORG:{org}")
    if phone:  lines.append(f"TEL:{phone}")
    if email:  lines.append(f"EMAIL:{email}")
    if url:    lines.append(f"URL:{url}")
    lines.append("END:VCARD")
    return "\n".join(lines)


def build_wifi(ssid, password, security, hidden):
    h = "true" if hidden else "false"
    return f"WIFI:T:{security};S:{ssid};P:{password};H:{h};;"


# ------------------------------------------------------------------ #
# QR generation
# ------------------------------------------------------------------ #
EC_MAP = {
    'L': qrcode.constants.ERROR_CORRECT_L,
    'M': qrcode.constants.ERROR_CORRECT_M,
    'Q': qrcode.constants.ERROR_CORRECT_Q,
    'H': qrcode.constants.ERROR_CORRECT_H,
}

COLOR_MAP = {
    'black': ('#000000', '#ffffff'),
    'blue' : ('#1d4ed8', '#ffffff'),
    'dark' : ('#ffffff', '#1e293b'),
}

# In-memory store for last generated QR bytes (for download)
_last_qr_bytes = None


def generate_qr(content, size=300, error_correction='M', color='black'):
    """Generate QR code and return (base64_str, raw_png_bytes)."""
    global _last_qr_bytes

    ec     = EC_MAP.get(error_correction, qrcode.constants.ERROR_CORRECT_M)
    fg, bg = COLOR_MAP.get(color, ('#000000', '#ffffff'))

    box_size = max(1, size // 33)

    qr = qrcode.QRCode(
        error_correction=ec,
        box_size=box_size,
        border=4
    )
    qr.add_data(content)
    qr.make(fit=True)

    img = qr.make_image(fill_color=fg, back_color=bg)
    img = img.resize((size, size), Image.NEAREST)

    buf = io.BytesIO()
    img.save(buf, format='PNG')
    raw = buf.getvalue()

    _last_qr_bytes = raw
    return base64.b64encode(raw).decode('utf-8')


# ------------------------------------------------------------------ #
# QR reading
# ------------------------------------------------------------------ #
def read_qr_from_image(file_bytes):
    """Decode QR code from image bytes using multiple strategies."""
    import cv2
    import numpy as np

    try:
        img = Image.open(io.BytesIO(file_bytes)).convert('RGB')
    except Exception:
        return None

    # Strategy 1: pyzbar on original image
    try:
        codes = pyzbar_decode(img)
        if codes:
            return codes[0].data.decode('utf-8', errors='replace')
    except Exception:
        pass

    # Convert to OpenCV format for preprocessing
    cv_img = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)

    # Strategy 2: OpenCV QR detector on original
    try:
        detector = cv2.QRCodeDetector()
        data, _, _ = detector.detectAndDecode(cv_img)
        if data:
            return data
    except Exception:
        pass

    # Strategy 3: grayscale + threshold + pyzbar
    try:
        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        _, thresh = cv2.threshold(gray, 0, 255,
                                  cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        pil_thresh = Image.fromarray(thresh)
        codes = pyzbar_decode(pil_thresh)
        if codes:
            return codes[0].data.decode('utf-8', errors='replace')
    except Exception:
        pass

    # Strategy 4: grayscale + threshold + OpenCV detector
    try:
        data, _, _ = detector.detectAndDecode(
            cv2.cvtColor(np.array(pil_thresh), cv2.COLOR_GRAY2BGR)
        )
        if data:
            return data
    except Exception:
        pass

    # Strategy 5: sharpen + pyzbar
    try:
        gray   = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        sharp  = cv2.filter2D(gray, -1,
                     np.array([[-1,-1,-1],[-1,9,-1],[-1,-1,-1]]))
        _, sharp_thresh = cv2.threshold(sharp, 0, 255,
                                        cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        codes = pyzbar_decode(Image.fromarray(sharp_thresh))
        if codes:
            return codes[0].data.decode('utf-8', errors='replace')
        data, _, _ = detector.detectAndDecode(
            cv2.cvtColor(sharp_thresh, cv2.COLOR_GRAY2BGR)
        )
        if data:
            return data
    except Exception:
        pass

    # Strategy 6: upscale 2x + threshold + pyzbar
    try:
        gray    = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        upscale = cv2.resize(gray, (gray.shape[1]*2, gray.shape[0]*2),
                             interpolation=cv2.INTER_CUBIC)
        _, up_thresh = cv2.threshold(upscale, 0, 255,
                                     cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        codes = pyzbar_decode(Image.fromarray(up_thresh))
        if codes:
            return codes[0].data.decode('utf-8', errors='replace')
        data, _, _ = detector.detectAndDecode(
            cv2.cvtColor(up_thresh, cv2.COLOR_GRAY2BGR)
        )
        if data:
            return data
    except Exception:
        pass

    return None


def image_to_base64(file_bytes, max_size=300):
    """Convert uploaded image to small base64 thumbnail for preview."""
    try:
        img = Image.open(io.BytesIO(file_bytes))
        img.thumbnail((max_size, max_size))
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        return base64.b64encode(buf.getvalue()).decode('utf-8')
    except Exception:
        return None


# ------------------------------------------------------------------ #
# Routes
# ------------------------------------------------------------------ #
def setup_routes(app):

    @app.route('/')
    def index():
        return redirect(url_for('create'))


    # ---------------------------------------------------------------- #
    # GET  /create  — show form
    # POST /create  — generate QR code
    # ---------------------------------------------------------------- #
    @app.route('/create', methods=['GET', 'POST'])
    def create():
        if request.method == 'GET':
            return render_template('create.html')

        qr_type          = request.form.get('qr_type', 'text')
        size             = int(request.form.get('size', 300))
        error_correction = request.form.get('error_correction', 'M')
        color            = request.form.get('color', 'black')
        content          = ''

        if qr_type == 'text':
            content = request.form.get('text_content', '').strip()

        elif qr_type == 'url':
            content = request.form.get('url_content', '').strip()
            if content and not content.startswith(('http://', 'https://')):
                content = 'https://' + content

        elif qr_type == 'vcard':
            content = build_vcard(
                first = request.form.get('vcard_first', '').strip(),
                last  = request.form.get('vcard_last',  '').strip(),
                phone = request.form.get('vcard_phone', '').strip(),
                email = request.form.get('vcard_email', '').strip(),
                org   = request.form.get('vcard_org',   '').strip(),
                url   = request.form.get('vcard_url',   '').strip(),
            )

        elif qr_type == 'wifi':
            content = build_wifi(
                ssid     = request.form.get('wifi_ssid',     '').strip(),
                password = request.form.get('wifi_password', '').strip(),
                security = request.form.get('wifi_security', 'WPA'),
                hidden   = request.form.get('wifi_hidden') == 'true'
            )

        if not content or content in ('WIFI:T:WPA;S:;P:;H:false;;', 'BEGIN:VCARD'):
            flash('Please fill in the required fields.', 'error')
            return render_template('create.html', qr_type=qr_type)

        try:
            qr_image = generate_qr(content, size, error_correction, color)
        except Exception as e:
            flash(f'QR generation error: {e}', 'error')
            return render_template('create.html', qr_type=qr_type)

        display_content = content if len(content) <= 120 else content[:120] + '...'

        return render_template('create.html',
            qr_type     = qr_type,
            qr_image    = qr_image,
            qr_content  = display_content,
        )

    # ---------------------------------------------------------------- #
    # POST /download  — download last generated QR as PNG
    # ---------------------------------------------------------------- #
    @app.route('/download', methods=['POST'])
    def download():
        global _last_qr_bytes
        if not _last_qr_bytes:
            flash('No QR code to download. Please generate one first.', 'error')
            return redirect(url_for('create'))

        buf = io.BytesIO(_last_qr_bytes)
        buf.seek(0)
        return send_file(
            buf,
            mimetype='image/png',
            as_attachment=True,
            download_name='qrcode.png'
        )

    # ---------------------------------------------------------------- #
    # POST /scan_frame — decode a webcam frame sent as PNG (pyzbar)
    # ---------------------------------------------------------------- #
    @app.route('/scan_frame', methods=['POST'])
    def scan_frame():
        from flask import jsonify
        import base64, re

        data = request.get_json(silent=True) or {}
        image_data = data.get('image', '')

        if not image_data:
            return jsonify({'result': None, 'error': 'No image received'})

        # Strip data URL header: "data:image/png;base64,..."
        match = re.match(r'data:image/[^;]+;base64,(.*)', image_data, re.DOTALL)
        if not match:
            return jsonify({'result': None, 'error': 'Invalid image format'})

        try:
            file_bytes = base64.b64decode(match.group(1))
        except Exception:
            return jsonify({'result': None, 'error': 'Base64 decode failed'})

        result = read_qr_from_image(file_bytes)
        return jsonify({'result': result})

    # ---------------------------------------------------------------- #
    # GET  /read   — show read form
    # POST /read   — decode uploaded image
    # ---------------------------------------------------------------- #
    @app.route('/read', methods=['GET', 'POST'])
    def read():
        if request.method == 'GET':
            return render_template('read.html')

        file = request.files.get('qr_image')
        if not file or file.filename == '':
            flash('Please select an image file.', 'error')
            return render_template('read.html')

        file_bytes = file.read()
        result     = read_qr_from_image(file_bytes)
        preview    = image_to_base64(file_bytes)

        return render_template('read.html',
            upload_result  = result,
            upload_preview = preview
        )
