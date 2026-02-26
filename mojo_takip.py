import os
import csv
import subprocess
from datetime import datetime
from collections import defaultdict

# 1. Kontrol edilecek klasör yolları
KLASORLER = [
    "/home/axax/github/Practical-Mojo-Examples", 
    "/home/axax/Desktop/mojo_projects/"
]

# 2. Takip edilmesini İSTEMEDİĞİN dosya adlarını buraya ekle
YASAKLI_DOSYALAR = [
    "mojo_takip.py",
    "",   
]

CIKTI_DOSYASI = "mojo_karsilastirma_raporu.csv"

def dosya_bilgilerini_topla():
    dosya_matrisi = defaultdict(dict)
    
    for klasor in KLASORLER:
        klasor_yolu = os.path.expanduser(klasor)
        if not os.path.exists(klasor_yolu):
            print(f"Uyarı: {klasor_yolu} bulunamadı.")
            continue
            
        with os.scandir(klasor_yolu) as tarama:
            for girdi in tarama:
                # Sadece .py olsun, klasör olmasın ve yasaklı listesinde bulunmasın
                if (girdi.is_file() and 
                    (girdi.name.endswith('.mojo') or girdi.name.endswith('*.py'))  and 
                    girdi.name not in YASAKLI_DOSYALAR):
                    
                    istatistik = girdi.stat()
                    tarih = datetime.fromtimestamp(istatistik.st_mtime).strftime('%Y-%m-%d %H:%M')
                    boyut = f"{round(istatistik.st_size / 1024, 1)} KB"
                    
                    dosya_matrisi[girdi.name][klasor] = f"{tarih} | {boyut}"

    return dosya_matrisi

def csv_yaz(matris):
    if not matris:
        print("Kriterlere uygun dosya bulunamadı.")
        return

    basliklar = ["Dosya Adı"] + KLASORLER

    with open(CIKTI_DOSYASI, mode='w', encoding='utf-8', newline='') as f:
        yazici = csv.writer(f)
        yazici.writerow(basliklar)

        for dosya_adi in sorted(matris.keys()):
            satir = [dosya_adi]
            for klasor in KLASORLER:
                satir.append(matris[dosya_adi].get(klasor, "-"))
            yazici.writerow(satir)

    print(f"\nRapor hazırlandı! Harici tutulan dosya sayısı: {len(YASAKLI_DOSYALAR)}")
    print(f"Dosya: {os.path.abspath(CIKTI_DOSYASI)}")

def csv_yaz_ve_ac(matris):
    if not matris:
        print("Kriterlere uygun dosya bulunamadı.")
        return

    basliklar = ["Dosya Adı"] + KLASORLER

    with open(CIKTI_DOSYASI, mode='w', encoding='utf-8', newline='') as f:
        yazici = csv.writer(f)
        yazici.writerow(basliklar)
        for dosya_adi in sorted(matris.keys()):
            satir = [dosya_adi]
            for klasor in KLASORLER:
                satir.append(matris[dosya_adi].get(klasor, "-"))
            yazici.writerow(satir)

    tam_yol = os.path.abspath(CIKTI_DOSYASI)
    print(f"\nRapor hazırlandı: {tam_yol}")
    
    # Ubuntu'da dosyayı varsayılan uygulama (LibreOffice Calc) ile açar
    try:
        subprocess.run(['xdg-open', tam_yol])
    except Exception as e:
        print(f"Dosya otomatik açılamadı: {e}")

if __name__ == "__main__":
    sonuclar = dosya_bilgilerini_topla()
    # csv_yaz(sonuclar)
    csv_yaz_ve_ac(sonuclar)
