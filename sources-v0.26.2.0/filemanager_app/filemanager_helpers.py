"""
File Manager Flask route handler helper.
Imported by filemanager_app.mojo via Python.import_module().
"""

import os
import mimetypes
from datetime import datetime
from flask import (
    render_template, request, redirect, url_for,
    flash, send_from_directory
)
from werkzeug.utils import secure_filename

UPLOAD_FOLDER = "uploads"
MAX_MB        = 16

IMAGE_EXTS = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'}
PDF_EXTS   = {'.pdf'}
TEXT_EXTS  = {'.txt', '.md', '.csv', '.json', '.xml', '.yaml', '.yml',
              '.html', '.css', '.js', '.py', '.mojo', '.sh', '.ini',
              '.toml', '.log', '.ts', '.jsx', '.tsx', '.c', '.cpp',
              '.h', '.java', '.go', '.rs'}


def file_icon(ext):
    if ext in IMAGE_EXTS: return '🖼'
    if ext in PDF_EXTS:   return '📄'
    if ext in TEXT_EXTS:  return '📝'
    if ext in {'.zip', '.tar', '.gz', '.rar', '.7z'}: return '📦'
    if ext in {'.mp4', '.avi', '.mov', '.mkv'}:       return '🎬'
    if ext in {'.mp3', '.wav', '.ogg', '.flac'}:      return '🎵'
    if ext in {'.xls', '.xlsx', '.ods'}:              return '📊'
    if ext in {'.doc', '.docx', '.odt'}:              return '📃'
    return '📁'


def human_size(nbytes):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if nbytes < 1024:
            return f"{nbytes:.1f} {unit}"
        nbytes /= 1024
    return f"{nbytes:.1f} TB"


def file_info(filename):
    path = os.path.join(UPLOAD_FOLDER, filename)
    ext  = os.path.splitext(filename)[1].lower()
    stat = os.stat(path)
    return {
        'filename': filename,
        'ext'     : ext,
        'icon'    : file_icon(ext),
        'is_image': ext in IMAGE_EXTS,
        'is_pdf'  : ext in PDF_EXTS,
        'size'    : human_size(stat.st_size),
        'size_raw': stat.st_size,
        'date'    : datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M'),
    }


def get_all_files(filter_type='all'):
    if not os.path.exists(UPLOAD_FOLDER):
        return []
    files = []
    for fname in sorted(os.listdir(UPLOAD_FOLDER), reverse=True):
        fpath = os.path.join(UPLOAD_FOLDER, fname)
        if not os.path.isfile(fpath):
            continue
        info = file_info(fname)
        ext  = info['ext']
        if filter_type == 'image' and ext not in IMAGE_EXTS:
            continue
        if filter_type == 'pdf' and ext not in PDF_EXTS:
            continue
        if filter_type == 'other' and (ext in IMAGE_EXTS or ext in PDF_EXTS):
            continue
        files.append(info)
    return files


def get_stats():
    all_files = get_all_files()
    total_bytes = sum(f['size_raw'] for f in all_files)
    return {
        'count'     : len(all_files),
        'total_size': human_size(total_bytes),
        'images'    : sum(1 for f in all_files if f['ext'] in IMAGE_EXTS),
        'pdfs'      : sum(1 for f in all_files if f['ext'] in PDF_EXTS),
        'others'    : sum(1 for f in all_files
                          if f['ext'] not in IMAGE_EXTS
                          and f['ext'] not in PDF_EXTS),
    }


def setup_routes(app):

    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    app.config['MAX_CONTENT_LENGTH'] = MAX_MB * 1024 * 1024

    # ------------------------------------------------------------------ #
    # GET / — file list
    # ------------------------------------------------------------------ #
    @app.route('/')
    def index():
        filter_type = request.args.get('filter', 'all')
        files = get_all_files(filter_type)
        stats = get_stats()
        return render_template('index.html',
            files=files,
            stats=stats,
            filter=filter_type,
            max_mb=MAX_MB
        )

    # ------------------------------------------------------------------ #
    # POST /upload — handle file upload
    # ------------------------------------------------------------------ #
    @app.route('/upload', methods=['POST'])
    def upload():
        uploaded = request.files.getlist('files')
        if not uploaded or all(f.filename == '' for f in uploaded):
            flash('No files selected.', 'error')
            return redirect(url_for('index'))

        saved = 0
        for f in uploaded:
            if f.filename == '':
                continue
            filename = secure_filename(f.filename)
            if not filename:
                continue
            # If filename already exists, add timestamp
            base, ext = os.path.splitext(filename)
            dest = os.path.join(UPLOAD_FOLDER, filename)
            if os.path.exists(dest):
                ts       = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = f"{base}_{ts}{ext}"
                dest     = os.path.join(UPLOAD_FOLDER, filename)
            f.save(dest)
            saved += 1

        if saved:
            flash(f'{saved} file(s) uploaded successfully!', 'success')
        else:
            flash('No valid files were uploaded.', 'error')
        return redirect(url_for('index'))

    # ------------------------------------------------------------------ #
    # GET /preview/<filename> — preview a file
    # ------------------------------------------------------------------ #
    @app.route('/preview/<filename>')
    def preview(filename):
        filename = secure_filename(filename)
        path     = os.path.join(UPLOAD_FOLDER, filename)
        if not os.path.exists(path):
            flash('File not found.', 'error')
            return redirect(url_for('index'))

        ext       = os.path.splitext(filename)[1].lower()
        stat      = os.stat(path)
        size      = human_size(stat.st_size)
        date      = datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M')
        mime, _   = mimetypes.guess_type(filename)
        mime      = mime or 'application/octet-stream'
        icon      = file_icon(ext)
        content   = None

        if ext in IMAGE_EXTS:
            file_type = 'image'
        elif ext in PDF_EXTS:
            file_type = 'pdf'
        elif ext in TEXT_EXTS:
            file_type = 'text'
            try:
                with open(path, 'r', encoding='utf-8', errors='replace') as fh:
                    content = fh.read(20000)   # max 20KB for preview
                    if len(content) == 20000:
                        content += '\n\n[... file truncated for preview ...]'
            except Exception:
                content = '[Could not read file contents.]'
        else:
            file_type = 'other'

        return render_template('preview.html',
            filename=filename,
            file_type=file_type,
            size=size,
            date=date,
            mime=mime,
            icon=icon,
            content=content
        )

    # ------------------------------------------------------------------ #
    # GET /download/<filename> — download a file
    # ------------------------------------------------------------------ #
    @app.route('/download/<filename>')
    def download(filename):
        filename = secure_filename(filename)
        return send_from_directory(
            UPLOAD_FOLDER, filename, as_attachment=True
        )

    # ------------------------------------------------------------------ #
    # GET /uploads/<filename> — serve file for inline display
    # ------------------------------------------------------------------ #
    @app.route('/uploads/<filename>')
    def serve_file(filename):
        filename = secure_filename(filename)
        return send_from_directory(UPLOAD_FOLDER, filename)

    # ------------------------------------------------------------------ #
    # POST /delete/<filename> — delete a file
    # ------------------------------------------------------------------ #
    @app.route('/delete/<filename>', methods=['POST'])
    def delete_file(filename):
        filename = secure_filename(filename)
        path     = os.path.join(UPLOAD_FOLDER, filename)
        if os.path.exists(path):
            os.remove(path)
            flash(f'"{filename}" deleted.', 'success')
        else:
            flash('File not found.', 'error')
        ref = request.referrer or url_for('index')
        # If deleted from preview, go back to index
        if 'preview' in ref:
            return redirect(url_for('index'))
        return redirect(ref)
