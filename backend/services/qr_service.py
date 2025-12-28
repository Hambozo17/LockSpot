"""
QR Code Generation Service
"""

import qrcode
import io
import base64
from datetime import datetime
import hashlib
import secrets


def generate_qr_code_string(booking_id: int, code_type: str = "UNLOCK") -> str:
    """
    Generate a unique QR code string for locker access
    
    Args:
        booking_id: The booking ID
        code_type: Type of access (UNLOCK, LOCK, EMERGENCY)
    
    Returns:
        Unique QR code string
    """
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    random_part = secrets.token_hex(4).upper()
    
    code = f"LOCKSPOT-{booking_id}-{code_type}-{timestamp}-{random_part}"
    return code


def generate_qr_image_base64(data: str, size: int = 10, border: int = 2) -> str:
    """
    Generate a QR code image and return as base64 string
    
    Args:
        data: The data to encode in the QR code
        size: Box size (default 10)
        border: Border size (default 2)
    
    Returns:
        Base64 encoded PNG image string
    """
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=size,
        border=border,
    )
    
    qr.add_data(data)
    qr.make(fit=True)
    
    # Create image
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Convert to base64
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    buffer.seek(0)
    
    img_base64 = base64.b64encode(buffer.getvalue()).decode("utf-8")
    return img_base64


def validate_qr_code(code: str, booking_id: int) -> bool:
    """
    Validate a QR code string
    
    Args:
        code: QR code string to validate
        booking_id: Expected booking ID
    
    Returns:
        True if valid, False otherwise
    """
    try:
        parts = code.split("-")
        if len(parts) < 5:
            return False
        
        if parts[0] != "LOCKSPOT":
            return False
        
        if int(parts[1]) != booking_id:
            return False
        
        return True
    except Exception:
        return False


def generate_apk_download_qr(url: str) -> str:
    """
    Generate QR code for APK download link
    
    Args:
        url: Download URL for the APK
    
    Returns:
        Base64 encoded PNG image string
    """
    return generate_qr_image_base64(url, size=12, border=4)
