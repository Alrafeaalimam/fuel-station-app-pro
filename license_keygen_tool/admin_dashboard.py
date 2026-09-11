#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
لوحة تحكم إدارة العملاء والتراخيص الموحدة - نظام محطات الوقود ونظام المحلات
Unified License & Customer Admin Dashboard (Fuel Station Pro & Store POS)
=============================================================================
الميزات:
1. تعمل بسيرفر محلي مدمج في بايثون (بدون أي مكتبات خارجية).
2. قاعدة بيانات SQLite مشتركة وموسعة لدعم منتجين:
   - محطات الوقود (Fuel Station App Pro)
   - نقاط البيع وإدارة المحلات (Store Management POS)
3. توليد فوري لأكواد التفعيل المكونة من 8 خانات عبر SHA-256 المتوافقة مع التطبيق.
4. ميزة "إعادة تعيين الترخيص" لنقل ترخيص العميل لجهاز جديد مع الاحتفاظ بسجل تدقيق كامل للأجهزة السابقة.
5. إدارة حالة التراخيص: تجريبي (Trial) / مفعّل (Active) / منتهي (Expired).
=============================================================================
"""

import os
import sys
import json
import sqlite3
import hashlib
from datetime import datetime
from urllib.parse import urlparse, parse_qs
from http.server import HTTPServer, BaseHTTPRequestHandler

# ==============================================================================
# ⚙️ 1. إعدادات السيرفر وقاعدة البيانات
# ==============================================================================
PORT = int(os.environ.get("PORT", 8888))
HOST = "0.0.0.0"

DB_FILE_PATH = os.environ.get("LICENSES_DB_PATH") or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "licenses_db.sqlite"
)

# المفتاح السري الموحد وخوارزمية التشفير (مطابق لتطبيق Flutter بنسبة 100%)
SECRET_KEY = "STR-SEC-2026-X9K7-W4B8-9841F3E8"
CHARSET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"


# ==============================================================================
# 🔐 2. دوال خوارزمية التشفير وتوليد الأكواد
# ==============================================================================
def hash_to_code(payload: str) -> str:
    """تحويل النص إلى كود من 8 خانات بصيغة XXXX-XXXX عبر SHA-256"""
    digest_bytes = hashlib.sha256(payload.encode("utf-8")).digest()
    code_chars = [CHARSET[b % len(CHARSET)] for b in digest_bytes[:8]]
    raw = "".join(code_chars)
    return f"{raw[:4]}-{raw[4:]}"


def generate_activation_key(device_code: str) -> str:
    """توليد كود التفعيل المطابق لكود الجهاز المدخل"""
    clean_code = (
        device_code.replace("-", "").replace(" ", "").strip().upper()
    )
    if not clean_code:
        raise ValueError("كود الجهاز فارغ!")
    payload = f"LIC:{clean_code}:{SECRET_KEY}"
    return hash_to_code(payload)


# ==============================================================================
# 🗄️ 3. إدارة قاعدة البيانات المحلية (SQLite)
# ==============================================================================
def get_db_connection():
    """إنشاء اتصال مع قاعدة بيانات SQLite والتأكد من إنشاء المجلد"""
    db_dir = os.path.dirname(os.path.abspath(DB_FILE_PATH))
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)

    conn = sqlite3.connect(DB_FILE_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """تهيئة وتوسيع قاعدة البيانات لدعم منتجين مع سجل إعادة تعيين الأجهزة"""
    conn = get_db_connection()
    cursor = conn.cursor()

    # إنشاء جدول التراخيص الأساسي
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS licenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant_name TEXT NOT NULL,
            phone TEXT,
            device_code TEXT NOT NULL,
            activation_key TEXT NOT NULL,
            paid_amount REAL DEFAULT 0.0,
            notes TEXT,
            needs_follow_up INTEGER NOT NULL DEFAULT 0,
            product_type TEXT DEFAULT 'pos',
            status TEXT DEFAULT 'active',
            first_run_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )

    # ترقية الجدول الحالي في حال عدم وجود الأعمدة الجديدة
    cursor.execute("PRAGMA table_info(licenses)")
    cols = [col[1] for col in cursor.fetchall()]

    if "product_type" not in cols:
        cursor.execute("ALTER TABLE licenses ADD COLUMN product_type TEXT DEFAULT 'pos'")
        cursor.execute("UPDATE licenses SET product_type = 'pos' WHERE product_type IS NULL")

    if "status" not in cols:
        cursor.execute("ALTER TABLE licenses ADD COLUMN status TEXT DEFAULT 'active'")
        cursor.execute("UPDATE licenses SET status = 'active' WHERE status IS NULL")

    if "first_run_date" not in cols:
        cursor.execute("ALTER TABLE licenses ADD COLUMN first_run_date TEXT")

    # جدول السجل التاريخي لإعادة تعيين الأجهزة
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS license_device_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            license_id INTEGER NOT NULL,
            merchant_name TEXT,
            product_type TEXT NOT NULL,
            old_device_code TEXT NOT NULL,
            old_activation_key TEXT NOT NULL,
            new_device_code TEXT NOT NULL,
            new_activation_key TEXT NOT NULL,
            reason TEXT,
            reset_at TEXT NOT NULL,
            FOREIGN KEY (license_id) REFERENCES licenses (id)
        )
        """
    )

    conn.commit()
    conn.close()


# ==============================================================================
# 🌐 4. كود واجهة الويب (Single Page Application)
# ==============================================================================
DASHBOARD_HTML = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>لوحة إدارة التراخيص الموحدة - محطات الوقود ونقاط البيع</title>
  <style>
    :root {
      --primary: #0284c7;
      --primary-dark: #0369a1;
      --primary-light: #e0f2fe;
      --pos-color: #10b981;
      --fuel-color: #0284c7;
      --secondary: #1e293b;
      --bg: #f8fafc;
      --card: #ffffff;
      --text: #0f172a;
      --muted: #64748b;
      --border: #e2e8f0;
      --success: #10b981;
      --warning: #f59e0b;
      --danger: #ef4444;
      --shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -2px rgba(0, 0, 0, 0.05);
    }

    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; }
    body { background: var(--bg); color: var(--text); padding: 20px; line-height: 1.5; }
    .container { max-width: 1300px; margin: 0 auto; }

    header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; flex-wrap: wrap; gap: 16px; }
    .logo-area { display: flex; align-items: center; gap: 12px; }
    .logo-icon { width: 50px; height: 50px; background: var(--primary-light); color: var(--primary); border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 26px; font-weight: bold; }
    h1 { font-size: 22px; font-weight: 800; color: var(--secondary); }
    .db-badge { font-size: 11px; background: var(--border); padding: 4px 8px; border-radius: 6px; color: var(--muted); font-family: monospace; }

    /* التبويبات العلوية لاختيار المنتج */
    .product-tabs { display: flex; gap: 10px; margin-bottom: 20px; flex-wrap: wrap; }
    .product-tab {
      padding: 10px 20px;
      border-radius: 12px;
      border: 1px solid var(--border);
      background: var(--card);
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 8px;
      transition: all 0.2s;
    }
    .product-tab:hover { background: #f1f5f9; }
    .product-tab.active-all { background: var(--secondary); color: white; border-color: var(--secondary); }
    .product-tab.active-fuel { background: var(--fuel-color); color: white; border-color: var(--fuel-color); }
    .product-tab.active-pos { background: var(--pos-color); color: white; border-color: var(--pos-color); }

    /* الإحصائيات */
    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 16px; margin-bottom: 24px; }
    .stat-card { background: var(--card); border: 1px solid var(--border); border-radius: 16px; padding: 18px; box-shadow: var(--shadow); }
    .stat-label { font-size: 13px; color: var(--muted); margin-bottom: 6px; }
    .stat-value { font-size: 24px; font-weight: 800; color: var(--secondary); }
    .stat-sub { font-size: 11px; color: var(--muted); margin-top: 4px; }

    /* الشبكة الرئيسية */
    .main-grid { display: grid; grid-template-columns: 400px 1fr; gap: 24px; }
    @media (max-width: 980px) { .main-grid { grid-template-columns: 1fr; } }

    .card { background: var(--card); border: 1px solid var(--border); border-radius: 16px; padding: 20px; box-shadow: var(--shadow); margin-bottom: 20px; }
    .card-title { font-size: 16px; font-weight: 700; color: var(--secondary); margin-bottom: 16px; display: flex; justify-content: space-between; align-items: center; }

    .form-group { margin-bottom: 14px; }
    label { display: block; font-size: 12px; font-weight: 600; color: var(--muted); margin-bottom: 6px; }
    input, select, textarea {
      width: 100%; padding: 10px 14px; border-radius: 10px; border: 1px solid var(--border); font-size: 14px;
      outline: none; transition: border-color 0.2s; background: #fff;
    }
    input:focus, select:focus, textarea:focus { border-color: var(--primary); }
    .input-code { font-family: monospace; font-size: 16px; font-weight: bold; letter-spacing: 2px; text-transform: uppercase; }

    .btn {
      display: inline-flex; align-items: center; justify-content: center; gap: 8px;
      padding: 10px 18px; border-radius: 10px; border: none; font-size: 13px; font-weight: 700;
      cursor: pointer; transition: all 0.2s; background: var(--primary); color: #fff; width: 100%;
    }
    .btn:hover { opacity: 0.9; }
    .btn-secondary { background: var(--border); color: var(--text); width: auto; }
    .btn-secondary:hover { background: #cbd5e1; }
    .btn-warning { background: var(--warning); color: #fff; width: auto; }
    .btn-danger { background: var(--danger); color: #fff; width: auto; }
    .btn-sm { padding: 6px 12px; font-size: 12px; border-radius: 8px; width: auto; }

    .table-toolbar { display: flex; gap: 12px; margin-bottom: 16px; flex-wrap: wrap; }
    .search-input { flex: 1; min-width: 200px; }
    .filter-pills { display: flex; gap: 8px; }
    .pill { padding: 6px 14px; border-radius: 20px; font-size: 12px; font-weight: 600; border: 1px solid var(--border); background: #fff; cursor: pointer; }
    .pill.active { background: var(--secondary); color: #fff; border-color: var(--secondary); }

    .table-container { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; text-align: right; font-size: 13px; }
    th { padding: 12px 14px; background: #f8fafc; color: var(--muted); font-weight: 600; border-bottom: 1px solid var(--border); white-space: nowrap; }
    td { padding: 12px 14px; border-bottom: 1px solid var(--border); vertical-align: middle; }
    tr:hover { background: #f8fafc; }

    .badge { display: inline-flex; align-items: center; gap: 4px; padding: 4px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; }
    .badge-fuel { background: var(--primary-light); color: var(--fuel-color); border: 1px solid #bae6fd; }
    .badge-pos { background: #d1fae5; color: var(--pos-color); border: 1px solid #a7f3d0; }
    .badge-active { background: #dcfce7; color: #15803d; }
    .badge-trial { background: #fef3c7; color: #b45309; }
    .badge-expired { background: #fee2e2; color: #b91c1c; }

    .code-tag { font-family: monospace; font-weight: bold; background: #f1f5f9; padding: 3px 6px; border-radius: 6px; letter-spacing: 1px; }

    .actions-cell { display: flex; gap: 6px; align-items: center; }

    /* Modals */
    .modal-overlay { position: fixed; inset: 0; background: rgba(15, 23, 42, 0.6); display: none; align-items: center; justify-content: center; z-index: 100; backdrop-filter: blur(4px); }
    .modal { background: #fff; border-radius: 18px; width: 90%; max-width: 550px; padding: 24px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.2); max-height: 90vh; overflow-y: auto; }
    .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; }
    .close-btn { background: none; border: none; font-size: 22px; cursor: pointer; color: var(--muted); }

    .toast { position: fixed; bottom: 20px; left: 20px; background: var(--secondary); color: #fff; padding: 12px 20px; border-radius: 10px; font-size: 13px; font-weight: 600; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.3); display: none; z-index: 1000; }
  </style>
</head>
<body>

  <div class="container">
    <header>
      <div class="logo-area">
        <div class="logo-icon">🔑</div>
        <div>
          <h1>لوحة إدارة التراخيص والعملاء الموحدة</h1>
          <span class="db-badge" id="dbPathDisplay">SQLite Database</span>
        </div>
      </div>
      <div style="display:flex; gap:10px;">
        <button class="btn btn-secondary btn-sm" onclick="exportData()">📥 تصدير السجلات JSON</button>
      </div>
    </header>

    <!-- تبويبات اختيار المنتج الرئيسي -->
    <div class="product-tabs">
      <div class="product-tab active-all" id="tabAll" onclick="switchProductFilter('all')">
        🌐 جميع المنتجات (<span id="countAll">0</span>)
      </div>
      <div class="product-tab" id="tabFuel" onclick="switchProductFilter('fuel_station')">
        ⛽ محطات الوقود (Fuel Station Pro) (<span id="countFuel">0</span>)
      </div>
      <div class="product-tab" id="tabPos" onclick="switchProductFilter('pos')">
        🛒 نقاط البيع (Store POS) (<span id="countPos">0</span>)
      </div>
    </div>

    <!-- بطاقات الإحصائيات -->
    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-label">👥 إجمالي العملاء المعروضين</div>
        <div class="stat-value" id="statClients">0</div>
        <div class="stat-sub" id="statClientsSub">في الفلتر المحدد</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">✅ التراخيص المفعلة</div>
        <div class="stat-value" style="color: var(--success);" id="statActive">0</div>
        <div class="stat-sub">ترخيص تجاري نشط</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">⏳ الفترات التجريبية (Trial)</div>
        <div class="stat-value" style="color: var(--warning);" id="statTrial">0</div>
        <div class="stat-sub">عملاء قيد التجربة</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">💰 المبيعات المحصلة</div>
        <div class="stat-value" id="statRevenue">0.00 ج.س</div>
        <div class="stat-sub">إجمالي المدفوعات</div>
      </div>
    </div>

    <!-- الشبكة الرئيسية -->
    <div class="main-grid">
      
      <!-- العمود الأول: نموذج إضافة ترخيص جديد -->
      <div>
        <div class="card">
          <div class="card-title">✨ توليد ترخيص وتسجيل عميل جديد</div>
          <form id="newLicenseForm" onsubmit="handleCreateLicense(event)">
            
            <div class="form-group">
              <label>نوع المنتج *</label>
              <select id="inProductType" required onchange="handleProductChange(this.value)">
                <option value="fuel_station">⛽ محطة الوقود (Fuel Station App Pro)</option>
                <option value="pos">🛒 نظام إدارة المحلات (Store POS)</option>
              </select>
            </div>

            <div class="form-group">
              <label>كود الجهاز (Device Code / ID) *</label>
              <input type="text" id="inDeviceCode" class="input-code" placeholder="مثال: A3F9-K2M1" required autocomplete="off" oninput="handlePreviewKey(this.value)">
              <div id="keyPreviewBox" style="margin-top:6px; font-size:12px; display:none;">
                كود التفعيل المتوقع: <span class="code-tag" id="previewKeyVal" style="color:var(--primary-dark);"></span>
              </div>
            </div>

            <div class="form-group">
              <label id="labelMerchant">اسم المحطة / العميل *</label>
              <input type="text" id="inMerchantName" placeholder="مثال: محطة النيل - أم درمان" required>
            </div>

            <div class="form-group">
              <label>رقم هاتف العميل / واتساب</label>
              <input type="text" id="inPhone" placeholder="مثال: 09xxxxxxxx أو 249xxxxxxxxx">
            </div>

            <div class="form-group">
              <label>حالة الترخيص</label>
              <select id="inStatus">
                <option value="active">✅ مفعّل تجارياً (Active)</option>
                <option value="trial">⏳ فترة تجريبية (Trial - 7 أيام)</option>
                <option value="expired">🛑 منتهي الصلاحية (Expired)</option>
              </select>
            </div>

            <div class="form-group">
              <label>تاريخ أول تشغيل (اختياري)</label>
              <input type="date" id="inFirstRunDate">
            </div>

            <div class="form-group">
              <label>المبلغ المدفوع (ج.س / ر.س)</label>
              <input type="number" step="0.01" id="inAmount" placeholder="0.00" value="0">
            </div>

            <div class="form-group">
              <label>ملاحظات إضافية</label>
              <textarea id="inNotes" rows="2" placeholder="ملاحظات حول طريقة السداد، الجهاز، أو موقع المحطة..."></textarea>
            </div>

            <div class="form-group">
              <label style="display:flex; align-items:center; gap:8px; cursor:pointer;">
                <input type="checkbox" id="inFollowUp" style="width:auto;">
                <span>تحديد العميل كـ "يحتاج متابعة لاحقة" 🔔</span>
              </label>
            </div>

            <button type="submit" class="btn" id="submitBtn">
              <span>⚡ توليد كود التفعيل وحفظ السجل</span>
            </button>
          </form>
        </div>
      </div>

      <!-- العمود الثاني: جدول السجلات والبحث -->
      <div>
        <div class="card">
          <div class="table-toolbar">
            <input type="text" class="search-input" id="searchInput" placeholder="🔍 بحث بالاسم، الهاتف، أو كود الجهاز..." oninput="handleSearch(this.value)">
            <div class="filter-pills">
              <button class="pill active" id="filterStatusAll" onclick="setStatusFilter('all')">الكل</button>
              <button class="pill" id="filterStatusActive" onclick="setStatusFilter('active')">مفعّل</button>
              <button class="pill" id="filterStatusTrial" onclick="setStatusFilter('trial')">تجريبي</button>
              <button class="pill" id="filterFollowUp" onclick="setStatusFilter('follow_up')">متابعة 🔔</button>
            </div>
          </div>

          <div class="table-container">
            <table>
              <thead>
                <tr>
                  <th>المنتج</th>
                  <th>العميل / المحطة</th>
                  <th>الهاتف</th>
                  <th>كود الجهاز</th>
                  <th>كود التفعيل</th>
                  <th>الحالة</th>
                  <th>أول تشغيل</th>
                  <th>المبلغ</th>
                  <th>إجراءات</th>
                </tr>
              </thead>
              <tbody id="licensesTableBody">
                <tr><td colspan="9" style="text-align:center; color:var(--muted); padding:30px;">جاري تحميل البيانات...</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- Modal إعادة تعيين الترخيص لجهاز جديد (Reset Device) -->
  <div class="modal-overlay" id="resetDeviceModal">
    <div class="modal">
      <div class="modal-header">
        <h3 style="font-size:16px;">🔄 إعادة تعيين الترخيص لجهاز جديد</h3>
        <button class="close-btn" onclick="closeResetModal()">&times;</button>
      </div>
      <form id="resetDeviceForm" onsubmit="handleResetDeviceSubmit(event)">
        <input type="hidden" id="resetLicenseId">
        
        <div style="background:#f8fafc; border:1px solid var(--border); border-radius:12px; padding:14px; margin-bottom:16px;">
          <div style="font-size:13px; font-weight:700;" id="resetClientName">اسم العميل</div>
          <div style="font-size:12px; color:var(--muted); margin-top:4px;">
            الجهاز الحالي القديم: <span class="code-tag" id="resetOldDeviceCode"></span>
          </div>
        </div>

        <div class="form-group">
          <label>كود الجهاز الجديد (New Device ID) *</label>
          <input type="text" id="resetNewDeviceCode" class="input-code" placeholder="مثال: X8K2-9M4Q" required autocomplete="off" oninput="handleResetPreview(this.value)">
          <div id="resetPreviewBox" style="margin-top:6px; font-size:12px; display:none;">
            كود التفعيل الجديد: <span class="code-tag" id="resetPreviewKeyVal" style="color:var(--success);"></span>
          </div>
        </div>

        <div class="form-group">
          <label>سبب إعادة التعيين (أسباب المراجعة والتدقيق) *</label>
          <input type="text" id="resetReason" placeholder="مثال: تلف اللوحة الأم للجهاز القديم واستبداله بكمبيوتر جديد" required>
        </div>

        <div style="font-size:12px; color:var(--warning); background:#fffbeb; padding:10px; border-radius:8px; border:1px solid #fde68a; margin-bottom:16px;">
          ⚠️ سيتم إبطال الربط بالجهاز القديم وحفظه في سجل المراجعة، ولن يعمل كود الجهاز القديم مجدداً.
        </div>

        <div style="display:flex; gap:10px;">
          <button type="button" class="btn btn-secondary" onclick="closeResetModal()">إلغاء</button>
          <button type="submit" class="btn btn-warning">🔄 اعتماد الجهاز الجديد وتوليد الكود</button>
        </div>
      </form>
    </div>
  </div>

  <!-- Modal عرض السجل التاريخي للأجهزة (Device History) -->
  <div class="modal-overlay" id="historyModal">
    <div class="modal" style="max-width:700px;">
      <div class="modal-header">
        <h3 style="font-size:16px;">📜 السجل التاريخي للأجهزة - <span id="historyClientName"></span></h3>
        <button class="close-btn" onclick="closeHistoryModal()">&times;</button>
      </div>
      <div id="historyContent">
        جاري التحميل...
      </div>
      <div style="margin-top:16px; text-align:left;">
        <button class="btn btn-secondary btn-sm" onclick="closeHistoryModal()">إغلاق</button>
      </div>
    </div>
  </div>

  <!-- Modal تعديل بيانات العميل -->
  <div class="modal-overlay" id="editModal">
    <div class="modal">
      <div class="modal-header">
        <h3 style="font-size:16px;">✏️ تعديل بيانات العميل والترخيص</h3>
        <button class="close-btn" onclick="closeEditModal()">&times;</button>
      </div>
      <form id="editForm" onsubmit="handleUpdateLicense(event)">
        <input type="hidden" id="editId">
        
        <div class="form-group">
          <label>نوع المنتج</label>
          <select id="editProductType">
            <option value="fuel_station">⛽ محطة الوقود (Fuel Station App Pro)</option>
            <option value="pos">🛒 نظام إدارة المحلات (Store POS)</option>
          </select>
        </div>

        <div class="form-group">
          <label>اسم التاجر / المحطة</label>
          <input type="text" id="editMerchantName" required>
        </div>

        <div class="form-group">
          <label>رقم الهاتف</label>
          <input type="text" id="editPhone">
        </div>

        <div class="form-group">
          <label>حالة الترخيص</label>
          <select id="editStatus">
            <option value="active">مفعّل (Active)</option>
            <option value="trial">فترة تجريبية (Trial)</option>
            <option value="expired">منتهي (Expired)</option>
          </select>
        </div>

        <div class="form-group">
          <label>تاريخ أول تشغيل</label>
          <input type="date" id="editFirstRunDate">
        </div>

        <div class="form-group">
          <label>المبلغ المدفوع</label>
          <input type="number" step="0.01" id="editAmount">
        </div>

        <div class="form-group">
          <label>ملاحظات</label>
          <textarea id="editNotes" rows="3"></textarea>
        </div>

        <div class="form-group">
          <label style="display:flex; align-items:center; gap:8px; cursor:pointer;">
            <input type="checkbox" id="editFollowUp" style="width:auto;">
            <span>يحتاج متابعة لاحقة</span>
          </label>
        </div>

        <div style="display:flex; gap:10px; margin-top:20px;">
          <button type="button" class="btn btn-secondary" onclick="closeEditModal()">إلغاء</button>
          <button type="submit" class="btn">حفظ التعديلات</button>
        </div>
      </form>
    </div>
  </div>

  <!-- Modal عرض الكود المولد -->
  <div class="modal-overlay" id="keyGeneratedModal">
    <div class="modal" style="text-align:center;">
      <div style="font-size:44px; margin-bottom:10px;">🎉</div>
      <h3 style="font-size:18px; margin-bottom:6px;" id="genModalTitle">تم توليد كود التفعيل بنجاح</h3>
      <p style="font-size:13px; color:var(--muted); margin-bottom:20px;" id="genModalSub">أرسل هذا الكود للعميل لتفعيل التطبيق</p>
      
      <div style="background:#f1f5f9; padding:18px; border-radius:14px; margin-bottom:20px;">
        <div style="font-size:11px; color:var(--muted); margin-bottom:6px;">كود التفعيل (Activation Key)</div>
        <div id="genKeyDisplay" style="font-family:monospace; font-size:28px; font-weight:900; letter-spacing:3px; color:var(--primary-dark);">XXXX-XXXX</div>
      </div>

      <div style="display:flex; gap:10px;">
        <button class="btn btn-secondary" onclick="closeGeneratedModal()">إغلاق</button>
        <button class="btn" onclick="copyGeneratedKey()">📋 نسخ الكود</button>
      </div>
    </div>
  </div>

  <!-- Toast للإشعارات السريعة -->
  <div class="toast" id="toast"></div>

  <script>
    let allLicenses = [];
    let currentProductFilter = 'all'; // 'all', 'fuel_station', 'pos'
    let currentStatusFilter = 'all';  // 'all', 'active', 'trial', 'follow_up'
    let searchQuery = '';

    const SECRET_KEY = "STR-SEC-2026-X9K7-W4B8-9841F3E8";
    const CHARSET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

    // توليد المعاينة في المتصفح فوراً
    async function sha256Browser(str) {
      const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
      return Array.from(new Uint8Array(buf));
    }

    async function generateKeyClient(deviceCode) {
      const clean = deviceCode.replace(/[- ]/g, '').trim().toUpperCase();
      if (!clean) return '';
      const payload = `LIC:${clean}:${SECRET_KEY}`;
      const bytes = await sha256Browser(payload);
      let raw = '';
      for (let i = 0; i < 8; i++) {
        raw += CHARSET[bytes[i] % CHARSET.length];
      }
      return `${raw.substring(0, 4)}-${raw.substring(4, 8)}`;
    }

    async function handlePreviewKey(val) {
      const box = document.getElementById('keyPreviewBox');
      const text = document.getElementById('previewKeyVal');
      if (!val.trim()) { box.style.display = 'none'; return; }
      const key = await generateKeyClient(val);
      text.innerText = key;
      box.style.display = 'block';
    }

    async function handleResetPreview(val) {
      const box = document.getElementById('resetPreviewBox');
      const text = document.getElementById('resetPreviewKeyVal');
      if (!val.trim()) { box.style.display = 'none'; return; }
      const key = await generateKeyClient(val);
      text.innerText = key;
      box.style.display = 'block';
    }

    function handleProductChange(val) {
      const label = document.getElementById('labelMerchant');
      if (val === 'fuel_station') {
        label.innerText = 'اسم المحطة / العميل *';
      } else {
        label.innerText = 'اسم التاجر / المتجر *';
      }
    }

    window.addEventListener('DOMContentLoaded', () => {
      document.getElementById('inFirstRunDate').value = new Date().toISOString().substring(0, 10);
      loadLicenses();
    });

    async function loadLicenses() {
      try {
        const res = await fetch('/api/licenses');
        const data = await res.json();
        allLicenses = data.licenses || [];
        document.getElementById('dbPathDisplay').innerText = data.db_path || 'SQLite';
        updateStatsAndTabs();
        renderTable();
      } catch (err) {
        showToast('تعذر تحميل البيانات: ' + err);
      }
    }

    function switchProductFilter(prod) {
      currentProductFilter = prod;
      document.getElementById('tabAll').className = 'product-tab' + (prod === 'all' ? ' active-all' : '');
      document.getElementById('tabFuel').className = 'product-tab' + (prod === 'fuel_station' ? ' active-fuel' : '');
      document.getElementById('tabPos').className = 'product-tab' + (prod === 'pos' ? ' active-pos' : '');
      
      // مزامنة النموذج مع التبويب
      if (prod === 'fuel_station') {
        document.getElementById('inProductType').value = 'fuel_station';
        handleProductChange('fuel_station');
      } else if (prod === 'pos') {
        document.getElementById('inProductType').value = 'pos';
        handleProductChange('pos');
      }

      updateStatsAndTabs();
      renderTable();
    }

    function setStatusFilter(st) {
      currentStatusFilter = st;
      document.getElementById('filterStatusAll').classList.toggle('active', st === 'all');
      document.getElementById('filterStatusActive').classList.toggle('active', st === 'active');
      document.getElementById('filterStatusTrial').classList.toggle('active', st === 'trial');
      document.getElementById('filterFollowUp').classList.toggle('active', st === 'follow_up');
      renderTable();
    }

    function updateStatsAndTabs() {
      const totalAll = allLicenses.length;
      const totalFuel = allLicenses.filter(x => (x.product_type || 'pos') === 'fuel_station').length;
      const totalPos = allLicenses.filter(x => (x.product_type || 'pos') === 'pos').length;

      document.getElementById('countAll').innerText = totalAll;
      document.getElementById('countFuel').innerText = totalFuel;
      document.getElementById('countPos').innerText = totalPos;

      // تصفية السجلات حسب التبويب النشط لحساب الإحصائيات
      let filteredByProduct = allLicenses;
      if (currentProductFilter !== 'all') {
        filteredByProduct = allLicenses.filter(x => (x.product_type || 'pos') === currentProductFilter);
      }

      const activeCount = filteredByProduct.filter(x => (x.status || 'active') === 'active').length;
      const trialCount = filteredByProduct.filter(x => (x.status || 'active') === 'trial').length;
      const totalRev = filteredByProduct.reduce((acc, x) => acc + (parseFloat(x.paid_amount) || 0), 0);

      document.getElementById('statClients').innerText = filteredByProduct.length;
      document.getElementById('statActive').innerText = activeCount;
      document.getElementById('statTrial').innerText = trialCount;
      document.getElementById('statRevenue').innerText = totalRev.toLocaleString('en-US', { minimumFractionDigits: 2 }) + ' ج.س';
    }

    function renderTable() {
      const tbody = document.getElementById('licensesTableBody');
      tbody.innerHTML = '';

      let list = allLicenses;

      // فلترة المنتج
      if (currentProductFilter !== 'all') {
        list = list.filter(x => (x.product_type || 'pos') === currentProductFilter);
      }

      // فلترة الحالة
      if (currentStatusFilter === 'active') {
        list = list.filter(x => (x.status || 'active') === 'active');
      } else if (currentStatusFilter === 'trial') {
        list = list.filter(x => (x.status || 'active') === 'trial');
      } else if (currentStatusFilter === 'follow_up') {
        list = list.filter(x => x.needs_follow_up === 1);
      }

      // البحث
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        list = list.filter(x => 
          (x.merchant_name && x.merchant_name.toLowerCase().includes(q)) ||
          (x.phone && x.phone.toLowerCase().includes(q)) ||
          (x.device_code && x.device_code.toLowerCase().includes(q)) ||
          (x.activation_key && x.activation_key.toLowerCase().includes(q))
        );
      }

      if (list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" style="text-align:center; color:var(--muted); padding:30px;">لا توجد سجلات مطابقة للفلتر المحدد.</td></tr>';
        return;
      }

      list.forEach((item, idx) => {
        const tr = document.createElement('tr');
        const prod = item.product_type || 'pos';
        const isFuel = prod === 'fuel_station';
        const st = item.status || 'active';

        let badgeStatus = '<span class="badge badge-active">مفعّل</span>';
        if (st === 'trial') badgeStatus = '<span class="badge badge-trial">تجريبي</span>';
        else if (st === 'expired') badgeStatus = '<span class="badge badge-expired">منتهي</span>';

        const prodBadge = isFuel 
          ? '<span class="badge badge-fuel">⛽ محطة وقود</span>'
          : '<span class="badge badge-pos">🛒 متجر POS</span>';

        const firstDate = item.first_run_date || (item.created_at ? item.created_at.substring(0, 10) : '-');

        tr.innerHTML = `
          <td>${prodBadge}</td>
          <td><strong>${escapeHtml(item.merchant_name)}</strong></td>
          <td dir="ltr" style="text-align:right;">${escapeHtml(item.phone || '-')}</td>
          <td><span class="code-tag">${escapeHtml(item.device_code)}</span></td>
          <td><span class="code-tag" style="color:var(--primary-dark);">${escapeHtml(item.activation_key)}</span></td>
          <td>${badgeStatus}</td>
          <td>${firstDate}</td>
          <td>${parseFloat(item.paid_amount || 0).toLocaleString()}</td>
          <td>
            <div class="actions-cell">
              <button class="btn btn-secondary btn-sm" title="نسخ كود التفعيل" onclick="copyText('${item.activation_key}')">📋</button>
              <button class="btn btn-warning btn-sm" title="إعادة تعيين لجهاز جديد" onclick="openResetModal(${item.id})">🔄 نقل</button>
              <button class="btn btn-secondary btn-sm" title="سجل الأجهزة السابقة" onclick="openHistoryModal(${item.id})">📜</button>
              <button class="btn btn-secondary btn-sm" title="تعديل" onclick="openEditModal(${item.id})">✏️</button>
              <button class="btn btn-danger btn-sm" title="حذف" onclick="deleteLicense(${item.id})">🗑️</button>
            </div>
          </td>
        `;
        tbody.appendChild(tr);
      });
    }

    async function handleCreateLicense(e) {
      e.preventDefault();
      const product_type = document.getElementById('inProductType').value;
      const device_code = document.getElementById('inDeviceCode').value.trim();
      const merchant_name = document.getElementById('inMerchantName').value.trim();
      const phone = document.getElementById('inPhone').value.trim();
      const status = document.getElementById('inStatus').value;
      const first_run_date = document.getElementById('inFirstRunDate').value;
      const paid_amount = parseFloat(document.getElementById('inAmount').value) || 0.0;
      const notes = document.getElementById('inNotes').value.trim();
      const needs_follow_up = document.getElementById('inFollowUp').checked ? 1 : 0;

      try {
        const res = await fetch('/api/licenses', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            product_type, device_code, merchant_name, phone, status, first_run_date, paid_amount, notes, needs_follow_up
          })
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'فشل التوليد');

        document.getElementById('genKeyDisplay').innerText = data.license.activation_key;
        document.getElementById('genModalTitle').innerText = 'تم توليد كود الترخيص بنجاح';
        document.getElementById('genModalSub').innerText = `للعميل: ${merchant_name} (${product_type === 'fuel_station' ? 'محطة وقود' : 'متجر'})`;
        document.getElementById('keyGeneratedModal').style.display = 'flex';

        // إعادة تعيين النموذج
        document.getElementById('newLicenseForm').reset();
        document.getElementById('inProductType').value = product_type;
        document.getElementById('keyPreviewBox').style.display = 'none';

        loadLicenses();
      } catch (err) {
        alert('خطأ: ' + err.message);
      }
    }

    // إدارة Modal إعادة تعيين الجهاز (Reset Device)
    function openResetModal(id) {
      const item = allLicenses.find(x => x.id === id);
      if (!item) return;

      document.getElementById('resetLicenseId').value = item.id;
      document.getElementById('resetClientName').innerText = item.merchant_name;
      document.getElementById('resetOldDeviceCode').innerText = item.device_code;
      document.getElementById('resetNewDeviceCode').value = '';
      document.getElementById('resetReason').value = '';
      document.getElementById('resetPreviewBox').style.display = 'none';

      document.getElementById('resetDeviceModal').style.display = 'flex';
    }

    function closeResetModal() {
      document.getElementById('resetDeviceModal').style.display = 'none';
    }

    async function handleResetDeviceSubmit(e) {
      e.preventDefault();
      const id = document.getElementById('resetLicenseId').value;
      const new_device_code = document.getElementById('resetNewDeviceCode').value.trim();
      const reason = document.getElementById('resetReason').value.trim();

      try {
        const res = await fetch(`/api/licenses/${id}/reset-device`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ new_device_code, reason })
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'فشل إعادة التعيين');

        closeResetModal();

        document.getElementById('genKeyDisplay').innerText = data.new_activation_key;
        document.getElementById('genModalTitle').innerText = 'تم ربط الترخيص بالجهاز الجديد بنجاح!';
        document.getElementById('genModalSub').innerText = `كود الجهاز الجديد: ${new_device_code}`;
        document.getElementById('keyGeneratedModal').style.display = 'flex';

        loadLicenses();
      } catch (err) {
        alert('خطأ: ' + err.message);
      }
    }

    // إدارة Modal السجل التاريخي (History)
    async function openHistoryModal(id) {
      const item = allLicenses.find(x => x.id === id);
      if (!item) return;

      document.getElementById('historyClientName').innerText = item.merchant_name;
      document.getElementById('historyContent').innerHTML = 'جاري التحميل...';
      document.getElementById('historyModal').style.display = 'flex';

      try {
        const res = await fetch(`/api/licenses/${id}/history`);
        const data = await res.json();
        const list = data.history || [];

        if (list.length === 0) {
          document.getElementById('historyContent').innerHTML = `
            <div style="text-align:center; color:var(--muted); padding:20px;">
              لا توجد عمليات نقل أو إعادة تعيين سابقة لهذا العميل. العميل يعمل على جهازه الأول: <span class="code-tag">${item.device_code}</span>
            </div>
          `;
          return;
        }

        let html = `
          <div style="font-size:12px; margin-bottom:10px; color:var(--muted);">
            إجمالي عمليات استبدال الأجهزة السابقة: <strong>${list.length}</strong>
          </div>
          <table style="font-size:12px;">
            <thead>
              <tr>
                <th>التاريخ</th>
                <th>الجهاز القديم</th>
                <th>الجهاز الجديد</th>
                <th>السبب والملاحظات</th>
              </tr>
            </thead>
            <tbody>
        `;
        list.forEach(h => {
          html += `
            <tr>
              <td>${h.reset_at.substring(0, 16).replace('T', ' ')}</td>
              <td><span class="code-tag">${h.old_device_code}</span></td>
              <td><span class="code-tag" style="color:var(--success);">${h.new_device_code}</span></td>
              <td>${escapeHtml(h.reason || '-')}</td>
            </tr>
          `;
        });
        html += '</tbody></table>';
        document.getElementById('historyContent').innerHTML = html;
      } catch (err) {
        document.getElementById('historyContent').innerHTML = 'تعذر تحميل السجل: ' + err;
      }
    }

    function closeHistoryModal() {
      document.getElementById('historyModal').style.display = 'none';
    }

    // Edit Modal
    function openEditModal(id) {
      const item = allLicenses.find(x => x.id === id);
      if (!item) return;

      document.getElementById('editId').value = item.id;
      document.getElementById('editProductType').value = item.product_type || 'pos';
      document.getElementById('editMerchantName').value = item.merchant_name;
      document.getElementById('editPhone').value = item.phone || '';
      document.getElementById('editStatus').value = item.status || 'active';
      document.getElementById('editFirstRunDate').value = item.first_run_date || '';
      document.getElementById('editAmount').value = item.paid_amount || 0;
      document.getElementById('editNotes').value = item.notes || '';
      document.getElementById('editFollowUp').checked = item.needs_follow_up === 1;

      document.getElementById('editModal').style.display = 'flex';
    }

    function closeEditModal() {
      document.getElementById('editModal').style.display = 'none';
    }

    async function handleUpdateLicense(e) {
      e.preventDefault();
      const id = document.getElementById('editId').value;
      const product_type = document.getElementById('editProductType').value;
      const name = document.getElementById('editMerchantName').value.trim();
      const phone = document.getElementById('editPhone').value.trim();
      const status = document.getElementById('editStatus').value;
      const first_run_date = document.getElementById('editFirstRunDate').value;
      const amount = parseFloat(document.getElementById('editAmount').value) || 0.0;
      const notes = document.getElementById('editNotes').value.trim();
      const followUp = document.getElementById('editFollowUp').checked ? 1 : 0;

      try {
        const res = await fetch(`/api/licenses/${id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            product_type,
            merchant_name: name,
            phone: phone,
            status: status,
            first_run_date: first_run_date,
            paid_amount: amount,
            notes: notes,
            needs_follow_up: followUp
          })
        });

        if (!res.ok) throw new Error('فشل التعديل');
        closeEditModal();
        showToast('تم حفظ التعديلات بنجاح');
        loadLicenses();
      } catch (err) {
        alert('خطأ: ' + err.message);
      }
    }

    async function deleteLicense(id) {
      const item = allLicenses.find(x => x.id === id);
      if (!item) return;

      if (!confirm(`هل أنت متأكد من حذف سجل "${item.merchant_name}" وسجل أجهزته؟`)) {
        return;
      }

      try {
        const res = await fetch(`/api/licenses/${id}`, { method: 'DELETE' });
        if (res.ok) {
          showToast('تم حذف السجل بنجاح');
          loadLicenses();
        }
      } catch (err) {
        showToast('فشل الحذف: ' + err);
      }
    }

    function closeGeneratedModal() {
      document.getElementById('keyGeneratedModal').style.display = 'none';
    }

    function copyGeneratedKey() {
      const key = document.getElementById('genKeyDisplay').innerText;
      copyText(key);
    }

    function copyText(txt) {
      navigator.clipboard.writeText(txt).then(() => {
        showToast('✓ تم نسخ الكود: ' + txt);
      }).catch(() => {
        showToast('✓ الكود: ' + txt);
      });
    }

    function handleSearch(q) {
      searchQuery = q;
      renderTable();
    }

    function exportData() {
      const jsonStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(allLicenses, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", jsonStr);
      downloadAnchor.setAttribute("download", `licenses_backup_${new Date().toISOString().substring(0,10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    }

    function showToast(msg) {
      const t = document.getElementById('toast');
      t.innerText = msg;
      t.style.display = 'block';
      setTimeout(() => { t.style.display = 'none'; }, 3000);
    }

    function escapeHtml(text) {
      if (!text) return '';
      return String(text)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }
  </script>

</body>
</html>
"""


# ==============================================================================
# 🚀 5. معالج طلبات HTTP (REST API & Web Server)
# ==============================================================================
class LicenseDashboardHandler(BaseHTTPRequestHandler):
    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html_str, status=200):
        body = html_str.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        # 1. الواجهة الرسومية الرئيسية
        if path == "/":
            self._send_html(DASHBOARD_HTML)
            return

        # 2. جلب قائمة التراخيص
        if path == "/api/licenses":
            params = parse_qs(parsed.query)
            prod_filter = params.get("product", [None])[0]

            conn = get_db_connection()
            cursor = conn.cursor()
            if prod_filter:
                cursor.execute(
                    "SELECT * FROM licenses WHERE product_type = ? ORDER BY id DESC",
                    (prod_filter,),
                )
            else:
                cursor.execute("SELECT * FROM licenses ORDER BY id DESC")
            rows = cursor.fetchall()
            licenses = [dict(row) for row in rows]
            conn.close()
            self._send_json({"licenses": licenses, "db_path": DB_FILE_PATH})
            return

        # 3. جلب سجل الأجهزة السابقة لترخيص معين
        if path.startswith("/api/licenses/") and path.endswith("/history"):
            parts = path.split("/")
            try:
                record_id = int(parts[3])
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT * FROM license_device_history WHERE license_id = ? ORDER BY id DESC",
                    (record_id,),
                )
                rows = cursor.fetchall()
                history = [dict(row) for row in rows]
                conn.close()
                self._send_json({"history": history})
                return
            except Exception as e:
                self._send_json({"error": str(e)}, status=500)
                return

        self._send_json({"error": "المسار غير موجود"}, status=404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        # 1. إضافة ترخيص وعميل جديد وتوليد كود التفعيل
        if path == "/api/licenses":
            content_len = int(self.headers.get("Content-Length", 0))
            body_str = self.rfile.read(content_len).decode("utf-8")
            try:
                data = json.loads(body_str)
                product_type = data.get("product_type", "fuel_station").strip().lower()
                device_code = data.get("device_code", "").strip().upper()
                merchant_name = data.get("merchant_name", "").strip()
                phone = data.get("phone", "").strip()
                status = data.get("status", "active").strip().lower()
                first_run_date = data.get("first_run_date")
                paid_amount = float(data.get("paid_amount", 0.0))
                notes = data.get("notes", "").strip()
                needs_follow_up = 1 if data.get("needs_follow_up") else 0

                if not device_code:
                    self._send_json({"error": "كود الجهاز مطلوب!"}, status=400)
                    return
                if not merchant_name:
                    self._send_json({"error": "اسم العميل / المحطة مطلوب!"}, status=400)
                    return

                # توليد كود التفعيل 8 خانات
                activation_key = generate_activation_key(device_code)
                now_str = datetime.now().isoformat()
                if not first_run_date:
                    first_run_date = now_str[:10]

                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute(
                    """
                    INSERT INTO licenses (
                        merchant_name, phone, device_code, activation_key,
                        paid_amount, notes, needs_follow_up, product_type,
                        status, first_run_date, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        merchant_name,
                        phone,
                        device_code,
                        activation_key,
                        paid_amount,
                        notes,
                        needs_follow_up,
                        product_type,
                        status,
                        first_run_date,
                        now_str,
                        now_str,
                    ),
                )
                new_id = cursor.lastrowid
                conn.commit()
                conn.close()

                created_item = {
                    "id": new_id,
                    "merchant_name": merchant_name,
                    "phone": phone,
                    "device_code": device_code,
                    "activation_key": activation_key,
                    "paid_amount": paid_amount,
                    "notes": notes,
                    "needs_follow_up": needs_follow_up,
                    "product_type": product_type,
                    "status": status,
                    "first_run_date": first_run_date,
                    "created_at": now_str,
                }

                self._send_json({"success": True, "license": created_item}, status=201)
                return
            except Exception as e:
                self._send_json({"error": str(e)}, status=500)
                return

        # 2. إعادة تعيين الترخيص لجهاز جديد (Reset Device) مع حفظ السجل التاريخي
        if path.startswith("/api/licenses/") and path.endswith("/reset-device"):
            parts = path.split("/")
            try:
                record_id = int(parts[3])
                content_len = int(self.headers.get("Content-Length", 0))
                body_str = self.rfile.read(content_len).decode("utf-8")
                data = json.loads(body_str)

                new_device_code = data.get("new_device_code", "").strip().upper()
                reason = data.get("reason", "").strip()

                if not new_device_code:
                    self._send_json({"error": "كود الجهاز الجديد مطلوب!"}, status=400)
                    return

                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM licenses WHERE id = ?", (record_id,))
                row = cursor.fetchone()
                if not row:
                    conn.close()
                    self._send_json({"error": "سجل الترخيص غير موجود!"}, status=404)
                    return

                old_device_code = row["device_code"]
                old_activation_key = row["activation_key"]
                merchant_name = row["merchant_name"]
                product_type = row["product_type"] or "fuel_station"

                # توليد كود التفعيل للجهاز الجديد
                new_activation_key = generate_activation_key(new_device_code)
                now_str = datetime.now().isoformat()

                # حفظ السجل التاريخي في جدول license_device_history
                cursor.execute(
                    """
                    INSERT INTO license_device_history (
                        license_id, merchant_name, product_type,
                        old_device_code, old_activation_key,
                        new_device_code, new_activation_key,
                        reason, reset_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        record_id,
                        merchant_name,
                        product_type,
                        old_device_code,
                        old_activation_key,
                        new_device_code,
                        new_activation_key,
                        reason,
                        now_str,
                    ),
                )

                # تحديث سجل العميل الحالي بالجهاز الجديد وكود التفعيل الجديد
                cursor.execute(
                    """
                    UPDATE licenses 
                    SET device_code = ?, activation_key = ?, status = 'active', updated_at = ?
                    WHERE id = ?
                    """,
                    (new_device_code, new_activation_key, now_str, record_id),
                )

                conn.commit()
                conn.close()

                self._send_json(
                    {
                        "success": True,
                        "old_device_code": old_device_code,
                        "new_device_code": new_device_code,
                        "new_activation_key": new_activation_key,
                    }
                )
                return
            except Exception as e:
                self._send_json({"error": str(e)}, status=500)
                return

        self._send_json({"error": "المسار غير موجود"}, status=404)

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path.startswith("/api/licenses/"):
            parts = path.split("/")
            try:
                record_id = int(parts[3])
                content_len = int(self.headers.get("Content-Length", 0))
                body_str = self.rfile.read(content_len).decode("utf-8")
                data = json.loads(body_str)

                product_type = data.get("product_type", "fuel_station")
                merchant_name = data.get("merchant_name", "").strip()
                phone = data.get("phone", "").strip()
                status = data.get("status", "active")
                first_run_date = data.get("first_run_date")
                paid_amount = float(data.get("paid_amount", 0.0))
                notes = data.get("notes", "").strip()
                needs_follow_up = 1 if data.get("needs_follow_up") else 0
                now_str = datetime.now().isoformat()

                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute(
                    """
                    UPDATE licenses 
                    SET product_type = ?, merchant_name = ?, phone = ?, status = ?,
                        first_run_date = ?, paid_amount = ?, notes = ?, needs_follow_up = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    (
                        product_type,
                        merchant_name,
                        phone,
                        status,
                        first_run_date,
                        paid_amount,
                        notes,
                        needs_follow_up,
                        now_str,
                        record_id,
                    ),
                )
                conn.commit()
                conn.close()

                self._send_json({"success": True})
                return
            except Exception as e:
                self._send_json({"error": str(e)}, status=500)
                return

        self._send_json({"error": "المسار غير موجود"}, status=404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path.startswith("/api/licenses/"):
            parts = path.split("/")
            try:
                record_id = int(parts[3])
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute("DELETE FROM license_device_history WHERE license_id = ?", (record_id,))
                cursor.execute("DELETE FROM licenses WHERE id = ?", (record_id,))
                conn.commit()
                conn.close()
                self._send_json({"success": True})
                return
            except Exception as e:
                self._send_json({"error": str(e)}, status=500)
                return

        self._send_json({"error": "المسار غير موجود"}, status=404)


# ==============================================================================
# 🏁 6. نقطة انطلاق السيرفر
# ==============================================================================
def main():
    init_db()
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, LicenseDashboardHandler)

    print("=" * 75)
    print("   🚀 لوحة تحكم إدارة التراخيص الموحدة (محطات الوقود + نقاط البيع)")
    print("=" * 75)
    print(f"📁 مسار قاعدة بيانات SQLite: {os.path.abspath(DB_FILE_PATH)}")
    print(f"🌐 العنوان المحلي للمتصفح:  http://localhost:{PORT}")
    print(f"📱 للوصول من الشبكة المحلية: http://<عنوان-الآي-بي>:{PORT}")
    print("=" * 75)
    print("💡 اضغط Ctrl + C لإيقاف السيرفر في أي وقت.")
    print("-" * 75)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 تم إيقاف السيرفر بنجاح.")
        httpd.server_close()


if __name__ == "__main__":
    main()
