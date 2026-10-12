using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using System.Diagnostics;

namespace MozeMusicInstaller
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            try
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new InstallerForm());
            }
            catch (Exception ex)
            {
                MessageBox.Show("Kurulum sihirbazı başlatılırken hata oluştu / Error launching installer:\n\n" + ex.ToString(), "MozeMusic Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    public class InstallerForm : Form
    {
        // Colors
        private readonly Color ColBg = Color.FromArgb(18, 18, 22);
        private readonly Color ColSidebar = Color.FromArgb(25, 25, 30);
        private readonly Color ColCard = Color.FromArgb(32, 32, 38);
        private readonly Color ColCardBorder = Color.FromArgb(48, 48, 56);
        private readonly Color ColAccent = Color.FromArgb(230, 57, 70); // Moze Red
        private readonly Color ColAccentHover = Color.FromArgb(255, 75, 90);
        private readonly Color ColAccentDisabled = Color.FromArgb(70, 40, 45);
        private readonly Color ColText = Color.FromArgb(245, 245, 250);
        private readonly Color ColTextMuted = Color.FromArgb(160, 160, 175);
        private readonly Color ColTextDisabled = Color.FromArgb(100, 100, 110);
        private readonly Color ColStepActive = Color.FromArgb(230, 57, 70);
        private readonly Color ColStepDone = Color.FromArgb(46, 204, 113);

        private int currentStep = 1;
        private const int TotalSteps = 7;

        // UI Controls
        private Panel pnlSidebar;
        private Panel pnlContent;
        private Panel pnlBottom;
        private Button btnBack;
        private Button btnNext;
        private Button btnCancel;
        private Label lblPoweredBy;

        // Step Panels
        private Panel pnlStep1; // Welcome & Purpose
        private Panel pnlStep2; // Permissions
        private Panel pnlStep3; // Privacy Policy
        private Panel pnlStep4; // Terms & Agreement with Checkbox
        private Panel pnlStep5; // Installation Preferences
        private Panel pnlStep6; // Installing Progress
        private Panel pnlStep7; // Completed

        // Form elements across steps
        private CheckBox chkAgree;
        private TextBox txtInstallPath;
        private CheckBox chkDesktopShortcut;
        private CheckBox chkStartMenuShortcut;
        private SmoothProgressBar progressBar;
        private Label lblInstallStatus;
        private Label lblInstallDetail;
        private CheckBox chkLaunchApp;

        // Drag window support
        private bool isDragging = false;
        private Point dragCursorPoint;
        private Point dragFormPoint;

        public InstallerForm()
        {
#if LANG_EN
            this.Text = "MozeMusic Setup Wizard";
#else
            this.Text = "MozeMusic Kurulum Sihirbazı";
#endif
            this.Size = new Size(860, 600);
            this.MinimumSize = new Size(860, 600);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.None;
            this.BackColor = ColBg;
            this.DoubleBuffered = true;

            SetStyle(ControlStyles.ResizeRedraw | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true);

            InitializeComponents();
            ShowStep(1);
        }

        private void InitializeComponents()
        {
            // Titlebar / Drag Panel
            Panel pnlTitle = new Panel
            {
                Dock = DockStyle.Top,
                Height = 36,
                BackColor = ColSidebar
            };
            pnlTitle.MouseDown += Title_MouseDown;
            pnlTitle.MouseMove += Title_MouseMove;
            pnlTitle.MouseUp += Title_MouseUp;

            Label lblTitle = new Label
            {
#if LANG_EN
                Text = "MozeMusic Desktop Installer v1.0",
#else
                Text = "MozeMusic Masaüstü Kurulum Sihirbazı v1.0",
#endif
                ForeColor = ColTextMuted,
                Font = new Font("Segoe UI", 9f, FontStyle.Regular),
                Location = new Point(16, 9),
                AutoSize = true
            };
            lblTitle.MouseDown += Title_MouseDown;

            Button btnCloseTop = new Button
            {
                Text = "✕",
                Size = new Size(36, 36),
                Dock = DockStyle.Right,
                FlatStyle = FlatStyle.Flat,
                ForeColor = ColTextMuted,
                Font = new Font("Segoe UI", 10f),
                Cursor = Cursors.Hand
            };
            btnCloseTop.FlatAppearance.BorderSize = 0;
            btnCloseTop.FlatAppearance.BorderColor = ColSidebar;
            btnCloseTop.FlatAppearance.MouseOverBackColor = Color.FromArgb(200, 40, 50);
            btnCloseTop.Click += (s, e) => { if (ConfirmExit()) this.Close(); };

            Button btnMinTop = new Button
            {
                Text = "─",
                Size = new Size(36, 36),
                Dock = DockStyle.Right,
                FlatStyle = FlatStyle.Flat,
                ForeColor = ColTextMuted,
                Font = new Font("Segoe UI", 9f),
                Cursor = Cursors.Hand
            };
            btnMinTop.FlatAppearance.BorderSize = 0;
            btnMinTop.FlatAppearance.BorderColor = ColSidebar;
            btnMinTop.FlatAppearance.MouseOverBackColor = Color.FromArgb(40, 40, 48);
            btnMinTop.Click += (s, e) => this.WindowState = FormWindowState.Minimized;

            pnlTitle.Controls.Add(lblTitle);
            pnlTitle.Controls.Add(btnMinTop);
            pnlTitle.Controls.Add(btnCloseTop);
            this.Controls.Add(pnlTitle);

            // Left Sidebar
            pnlSidebar = new Panel
            {
                Dock = DockStyle.Left,
                Width = 240,
                BackColor = ColSidebar
            };
            pnlSidebar.Paint += Sidebar_Paint;

            // Powered by MozeLabs Link at bottom of sidebar
            lblPoweredBy = new Label
            {
                Text = "Powered by MozeLabs",
                ForeColor = ColTextMuted,
                Font = new Font("Segoe UI", 9.5f, FontStyle.Regular),
                Cursor = Cursors.Hand,
                AutoSize = false,
                Size = new Size(200, 24),
                Location = new Point(20, 526),
                TextAlign = ContentAlignment.MiddleLeft
            };
            lblPoweredBy.MouseEnter += (s, e) =>
            {
                lblPoweredBy.ForeColor = ColAccent;
                lblPoweredBy.Font = new Font("Segoe UI", 9.5f, FontStyle.Underline);
            };
            lblPoweredBy.MouseLeave += (s, e) =>
            {
                lblPoweredBy.ForeColor = ColTextMuted;
                lblPoweredBy.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);
            };
            lblPoweredBy.Click += (s, e) =>
            {
                try
                {
#if LANG_EN
                    string url = "https://mozelabs.com/en";
#else
                    string url = "https://mozelabs.com/tr";
#endif
                    Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
                }
                catch { }
            };
            pnlSidebar.Controls.Add(lblPoweredBy);

            this.Controls.Add(pnlSidebar);

            // Bottom Navigation Panel
            pnlBottom = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 64,
                BackColor = ColSidebar
            };
            pnlBottom.Paint += (s, e) =>
            {
                using (Pen p = new Pen(ColCardBorder, 1))
                {
                    e.Graphics.DrawLine(p, 0, 0, pnlBottom.Width, 0);
                }
            };

#if LANG_EN
            btnCancel = CreateStyledButton("Cancel", 90, false);
            btnNext = CreateStyledButton("Next >", 120, true);
            btnBack = CreateStyledButton("< Back", 90, false);
#else
            btnCancel = CreateStyledButton("İptal", 90, false);
            btnNext = CreateStyledButton("İleri >", 120, true);
            btnBack = CreateStyledButton("< Geri", 90, false);
#endif

            btnCancel.Location = new Point(pnlBottom.Width - 110, 16);
            btnCancel.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            btnCancel.Click += (s, e) => { if (ConfirmExit()) this.Close(); };

            btnNext.Location = new Point(pnlBottom.Width - 240, 16);
            btnNext.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            btnNext.Click += BtnNext_Click;

            btnBack.Location = new Point(pnlBottom.Width - 340, 16);
            btnBack.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            btnBack.Click += (s, e) => { if (currentStep > 1) ShowStep(currentStep - 1); };

            pnlBottom.Controls.Add(btnBack);
            pnlBottom.Controls.Add(btnNext);
            pnlBottom.Controls.Add(btnCancel);
            this.Controls.Add(pnlBottom);

            // Main Content Area
            pnlContent = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = ColBg,
                Padding = new Padding(28, 20, 28, 20)
            };
            this.Controls.Add(pnlContent);
            pnlContent.BringToFront();

            BuildStep1();
            BuildStep2();
            BuildStep3();
            BuildStep4();
            BuildStep5();
            BuildStep6();
            BuildStep7();
        }

        private Button CreateStyledButton(string text, int width, bool isPrimary)
        {
            Button btn = new Button
            {
                Text = text,
                Size = new Size(width, 36),
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                Cursor = Cursors.Hand,
                ForeColor = isPrimary ? Color.White : ColText
            };
            btn.FlatAppearance.BorderSize = isPrimary ? 0 : 1;
            btn.FlatAppearance.BorderColor = isPrimary ? ColAccent : ColCardBorder;
            btn.BackColor = isPrimary ? ColAccent : ColCard;

            btn.MouseEnter += (s, e) =>
            {
                if (btn.Enabled)
                    btn.BackColor = isPrimary ? ColAccentHover : Color.FromArgb(45, 45, 54);
            };
            btn.MouseLeave += (s, e) =>
            {
                if (btn.Enabled)
                    btn.BackColor = isPrimary ? ColAccent : ColCard;
            };

            return btn;
        }

        #region Step Panels

        // STEP 1: Welcome & App Purpose
        private void BuildStep1()
        {
            pnlStep1 = new Panel { Dock = DockStyle.Fill, Visible = false };

            Label lblHeading = new Label
            {
#if LANG_EN
                Text = "Welcome to MozeMusic",
#else
                Text = "MozeMusic'e Hoş Geldiniz",
#endif
                Font = new Font("Segoe UI", 18f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 0),
                AutoSize = true
            };

            Label lblSub = new Label
            {
#if LANG_EN
                Text = "Experience unlimited, ad-free, high-fidelity music designed for power users.",
#else
                Text = "Müziği sınır olmadan, yüksek kalite ve reklamsız olarak dinlemeniz için tasarlandı.",
#endif
                Font = new Font("Segoe UI", 10.5f),
                ForeColor = ColTextMuted,
                Location = new Point(2, 36),
                AutoSize = true
            };

            Panel cardPurpose = new Panel
            {
                Location = new Point(0, 76),
                Size = new Size(560, 340),
                BackColor = ColCard
            };
            cardPurpose.Paint += (s, e) =>
            {
                using (Pen p = new Pen(ColCardBorder, 1))
                {
                    e.Graphics.DrawRectangle(p, 0, 0, cardPurpose.Width - 1, cardPurpose.Height - 1);
                }
            };

            int topY = 16;
#if LANG_EN
            AddFeatureItem(cardPurpose, "🎵", "Unlimited Streaming & Smart Search", "Instant access to millions of songs, albums, and artists powered by high-speed streaming.", ref topY);
            AddFeatureItem(cardPurpose, "🎧", "Lossless Audio Quality & Equalizer", "Crystal-clear sound engine supporting high-bitrate audio and customizable audio session profiles.", ref topY);
            AddFeatureItem(cardPurpose, "💾", "Offline Downloads & Local Storage", "Download songs directly to your PC for seamless offline listening with zero internet required.", ref topY);
            AddFeatureItem(cardPurpose, "👥", "Jam Room & Real-Time Sync", "Listen to music simultaneously with friends, share queues, and discover tunes together.", ref topY);
#else
            AddFeatureItem(cardPurpose, "🎵", "Sınırsız Şarkı & Akıllı Arama", "Milyonlarca parçaya anında erişin, popüler müzikleri ve sanatçıları yüksek hızda keşfedin.", ref topY);
            AddFeatureItem(cardPurpose, "🎧", "Kayıpsız Yüksek Ses Kalitesi", "Kristal netliğinde gelişmiş ses motoru ve Windows ses entegrasyonuyla kesintisiz müzik keyfi.", ref topY);
            AddFeatureItem(cardPurpose, "💾", "Çevrimdışı İndirme & Dinleme", "İstediğiniz şarkıları bilgisayarınıza indirin, internet bağlantısı olmadan dilediğinizce dinleyin.", ref topY);
            AddFeatureItem(cardPurpose, "👥", "Jam Room & Ortak Çalma", "Arkadaşlarınızla aynı anda aynı şarkıyı dinleyin, ortak kuyruklar oluşturun ve senkronize olun.", ref topY);
#endif

            pnlStep1.Controls.Add(lblHeading);
            pnlStep1.Controls.Add(lblSub);
            pnlStep1.Controls.Add(cardPurpose);
            pnlContent.Controls.Add(pnlStep1);
        }

        private void AddFeatureItem(Panel parent, string icon, string title, string desc, ref int topY)
        {
            Label lblIcon = new Label
            {
                Text = icon,
                Font = new Font("Segoe UI Emoji", 14f),
                ForeColor = ColAccent,
                Location = new Point(16, topY),
                Size = new Size(32, 32),
                TextAlign = ContentAlignment.MiddleCenter
            };
            Label lblTitle = new Label
            {
                Text = title,
                Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(56, topY),
                AutoSize = true
            };
            Label lblDesc = new Label
            {
                Text = desc,
                Font = new Font("Segoe UI", 9.5f),
                ForeColor = ColTextMuted,
                Location = new Point(56, topY + 22),
                Size = new Size(480, 36)
            };

            parent.Controls.Add(lblIcon);
            parent.Controls.Add(lblTitle);
            parent.Controls.Add(lblDesc);

            topY += 72;
        }

        // STEP 2: Application Permissions (Detailed)
        private void BuildStep2()
        {
            pnlStep2 = new Panel { Dock = DockStyle.Fill, Visible = false };

            Label lblHeading = new Label
            {
#if LANG_EN
                Text = "Application Permissions & System Access",
#else
                Text = "Uygulama İzinleri ve Sistem Erişimi",
#endif
                Font = new Font("Segoe UI", 17f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 0),
                AutoSize = true
            };

            Label lblSub = new Label
            {
#if LANG_EN
                Text = "MozeMusic requires the following hardware and system permissions to function properly.",
#else
                Text = "MozeMusic'in tam verimle çalışabilmesi için ihtiyaç duyduğu sistem izinleri ve amaçları:",
#endif
                Font = new Font("Segoe UI", 10f),
                ForeColor = ColTextMuted,
                Location = new Point(2, 34),
                AutoSize = true
            };

            RichTextBox rtbPermissions = new RichTextBox
            {
                Location = new Point(0, 70),
                Size = new Size(560, 340),
                BackColor = ColCard,
                ForeColor = ColText,
                BorderStyle = BorderStyle.None,
                Font = new Font("Segoe UI", 9.5f),
                ReadOnly = true,
                ScrollBars = RichTextBoxScrollBars.Vertical
            };

#if LANG_EN
            rtbPermissions.Text =
@"MOZEMUSIC PERMISSION & SYSTEM ACCESS SPECIFICATION

1. NETWORK & INTERNET ACCESS (Outbound HTTPS/WSS)
• Media Streaming: Downloads and buffers high-bitrate audio/video streams from YouTube & CDN endpoints.
• Cloud Sync: Connects securely to Google Firebase Firestore & Realtime Database for profile, playlist, and liked song synchronization.
• Album Art & Metadata: Fetches high-resolution thumbnails, artist profiles, and synchronized lyrics (LRC).
• Device Pairing: Facilitates QR-code and pairing session authentication.

2. AUDIO HARDWARE & WINDOWS MULTIMEDIA INTEGRATION
• Audio Output: Accesses default Windows Core Audio / DirectSound playback devices with dynamic device-switch detection.
• System Media Transport Controls (SMTC): Integrates with Windows Media Overlay, keyboard hardware media keys (Play/Pause, Next, Prev), and headset control buttons.
• Background Audio Session: Keeps music playback uninterrupted while the application is minimized or running in the background.

3. LOCAL STORAGE & OFFLINE FILE SYSTEM
• Application Directory: Installs required binaries, plugins, and Flutter assets into %LOCALAPPDATA%\Programs\MozeMusic.
• Offline Music Storage: Saves downloaded audio tracks and offline caches directly to your chosen local directory.
• Database Cache: Maintains a high-speed local Isar NoSQL database for instant offline library searches.

4. WINDOW & PROCESS MANAGEMENT
• System Tray & Mini Player: Allows minimizing to the Windows notification area and launching an overlay player.
• Desktop & Start Menu Shortcuts: Creates and manages quick launch shortcuts.";
#else
            rtbPermissions.Text =
@"MOZEMUSIC SİSTEM İZİNLERİ VE ERİŞİM BİLGİLENDİRMESİ

1. AĞ VE İNTERNET ERİŞİMİ İZNİ (Giden HTTPS / WSS Bağlantıları)
• Ses ve Medya Akışı: YouTube ve içerik sunucularından yüksek kaliteli ses/video akışlarının tamponlanması ve çalınması.
• Bulut Senkronizasyonu: Google Firebase Firestore ve Realtime Database üzerinden kullanıcı profili, çalma listeleri ve beğenilen şarkıların güvenli eşitlenmesi.
• Albüm Kapakları ve Sözler: Yüksek çözünürlüklü albüm kapak resimlerinin ve senkronize şarkı sözlerinin (LRC) anlık indirilmesi.
• Jam Room & Canlı Eşitleme: Arkadaşlarınızla aynı anda müzik dinleyebilmeniz için düşük gecikmeli veri akışı.

2. SES DONANIMI VE WINDOWS MEDYA ENTEGRASYONU İZNİ
• Ses Çıkışı Erişimi: Windows Core Audio ve DirectSound arabirimleri üzerinden varsayılan hoparlör/kulaklık aygıtına ses iletimi.
• Sistem Medya Taşıma Kontrolleri (SMTC): Klavyenizdeki medya tuşları (Oynat/Durdur, İleri, Geri), kulaklık kumandaları ve Windows ses çubuğu üzerinden müzik kontrolü.
• Arka Planda Çalma: Uygulama simge durumuna küçültüldüğünde müziğin kesintisiz devam edebilmesi.

3. YEREL DOSYA SİSTEMİ VE DEPOLAMA İZNİ
• Program Dizini Erişimi: Uygulama çekirdek dosyalarının %LOCALAPPDATA%\Programs\MozeMusic klasörüne güvenle kurulması.
• Çevrimdışı İndirme Depolaması: Kullanıcının tercih ettiği indirme klasörüne ses dosyalarının kaydedilmesi.
• Yerel Veritabanı (Isar Cache): İnternet yokken bile şarkı listenize ve geçmişinize anında erişim sağlayan yerel önbellek.

4. PENCERE VE ÇALIŞMA ALANI YÖNETİMİ
• Sistem Tepsisi (Tray) & Mini Player: Arka planda çalışma ve ekranın köşesinde mini oynatıcı gösterme yeteneği.
• Kısayol Oluşturma: Masaüstü ve Başlat Menüsüne program başlatma simgeleri ekleme.";
#endif

            pnlStep2.Controls.Add(lblHeading);
            pnlStep2.Controls.Add(lblSub);
            pnlStep2.Controls.Add(rtbPermissions);
            pnlContent.Controls.Add(pnlStep2);
        }

        // STEP 3: Privacy Policy (Detailed)
        private void BuildStep3()
        {
            pnlStep3 = new Panel { Dock = DockStyle.Fill, Visible = false };

            Label lblHeading = new Label
            {
#if LANG_EN
                Text = "Privacy Policy & Data Security",
#else
                Text = "Gizlilik Politikası ve Veri Güvenliği",
#endif
                Font = new Font("Segoe UI", 17f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 0),
                AutoSize = true
            };

            Label lblSub = new Label
            {
#if LANG_EN
                Text = "Learn how MozeMusic protects your data and respects your personal privacy.",
#else
                Text = "MozeMusic'in kişisel verilerinizi nasıl koruduğunu ve gizlilik ilkelerimizi inceleyin.",
#endif
                Font = new Font("Segoe UI", 10f),
                ForeColor = ColTextMuted,
                Location = new Point(2, 34),
                AutoSize = true
            };

            RichTextBox rtbPrivacy = new RichTextBox
            {
                Location = new Point(0, 70),
                Size = new Size(560, 340),
                BackColor = ColCard,
                ForeColor = ColText,
                BorderStyle = BorderStyle.None,
                Font = new Font("Segoe UI", 9.5f),
                ReadOnly = true,
                ScrollBars = RichTextBoxScrollBars.Vertical
            };

#if LANG_EN
            rtbPrivacy.Text =
@"MOZEMUSIC PRIVACY POLICY & DATA PROTECTION NOTICE

Last Updated: October 2026

1. PRIVACY-BY-DESIGN PHILOSOPHY
MozeMusic is built upon the fundamental principle that user listening habits and personal data belong solely to the user. We do not sell, rent, monetize, or broker your personal information to third-party advertising conglomerates.

2. AUTHENTICATION & GOOGLE ACCOUNT SECURITY
• Single Sign-On (SSO): Authentication occurs strictly through official Google OAuth 2.0 and Firebase Auth SDKs.
• Zero Password Storage: MozeMusic never requests, intercepts, or stores your Google password.
• Identity Tokens: Only encrypted identity tokens are used to authorize access to your personal cloud playlists.

3. DATA RETENTION & TELEMETRY
• Listening Library: Your liked tracks, created playlists, and listening history are tied exclusively to your account.
• No Tracking Cookies or Spyware: The desktop application does not include behavioral advertising trackers or background surveillance tools.
• Crash Reports: Anonymous, diagnostic stack traces may only be transmitted during critical exceptions to resolve bugs.

4. USER RIGHTS & DATA DELETION
Under KVKK and GDPR regulations, you hold full sovereignty over your data. You may export or permanently delete your account, saved playlists, and local offline files at any time through application settings.";
#else
            rtbPrivacy.Text =
@"MOZEMUSIC GİZLİLİK POLİTİKASI VE VERİ KORUMA METNİ

Son Güncelleme: Ekim 2026

1. TEMEL GİZLİLİK İLKEMİZ
MozeMusic, müzik dinleme alışkanlıklarınızın ve kişisel bilgilerinizin yalnızca size ait olduğunu kabul eder. Verileriniz hiçbir reklam şirketine, veri toplayıcısına veya ticari üçüncü tarafa satılmaz, devredilmez ve pazarlanmaz.

2. GÜVENLİ KİMLİK DOĞRULAMA (GOOGLE OAUTH & FIREBASE)
• Uçtan Uca Şifreli Oturum: Oturum açma işlemleri doğrudan resmi Google OAuth 2.0 ve Firebase altyapısı üzerinden gerçekleştirilir.
• Sıfır Şifre Barındırma: Google şifreniz hiçbir koşulda MozeMusic sunucularında veya yerel bilgisayarınızda tutulmaz.
• Oturum Tokenları: Yalnızca hesabınıza özel çalma listelerine erişim sağlayan kriptografik erişim belirteçleri kullanılır.

3. TOPLANAN VERİLER VE İŞLEME AMACI
• Müzik Kitaplığı: Beğendiğiniz şarkılar, oluşturduğunuz çalma listeleri ve dinleme geçmişiniz yalnızca size özel müzik deneyimi sunmak için kaydedilir.
• Reklam Takipsizliği: MozeMusic masaüstü uygulamasında hareketlerinizi izleyen hiçbir üçüncü taraf reklam kodu veya casus yazılım bulunmaz.
• Teşhis Bilgileri: Olası çökme ve hata durumlarında yalnızca programı iyileştirmek adına anonim hata kayıtları tutulabilir.

4. KULLANICI HAKLARI VE VERİ SİLME HAKKI (KVKK / GDPR)
Kişisel verileriniz üzerinde tam kontrol sahibisiniz. Dilediğiniz an hesap verilerinizi, oluşturduğunuz çalma listelerini ve indirilen dosyaları tamamen silebilirsiniz.";
#endif

            pnlStep3.Controls.Add(lblHeading);
            pnlStep3.Controls.Add(lblSub);
            pnlStep3.Controls.Add(rtbPrivacy);
            pnlContent.Controls.Add(pnlStep3);
        }

        // STEP 4: Terms of Service & EULA with Agreement Checkbox
        private void BuildStep4()
        {
            pnlStep4 = new Panel { Dock = DockStyle.Fill, Visible = false };

            Label lblHeading = new Label
            {
#if LANG_EN
                Text = "Terms of Service & User Agreement",
#else
                Text = "Kullanıcı Sözleşmesi ve Kullanım Şartları",
#endif
                Font = new Font("Segoe UI", 17f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 0),
                AutoSize = true
            };

            Label lblSub = new Label
            {
#if LANG_EN
                Text = "Please review the license terms. You must accept these terms to continue installation.",
#else
                Text = "Lütfen kullanım sözleşmesini inceleyin. Kuruluma devam etmek için şartları onaylamalısınız.",
#endif
                Font = new Font("Segoe UI", 10f),
                ForeColor = ColTextMuted,
                Location = new Point(2, 34),
                AutoSize = true
            };

            RichTextBox rtbTerms = new RichTextBox
            {
                Location = new Point(0, 68),
                Size = new Size(560, 270),
                BackColor = ColCard,
                ForeColor = ColText,
                BorderStyle = BorderStyle.None,
                Font = new Font("Segoe UI", 9.5f),
                ReadOnly = true,
                ScrollBars = RichTextBoxScrollBars.Vertical
            };

#if LANG_EN
            rtbTerms.Text =
@"MOZEMUSIC END USER LICENSE AGREEMENT & TERMS OF SERVICE

1. GRANT OF LICENSE
MozeMusic grants you a revocable, non-exclusive, non-transferable, limited license to download, install, and utilize the software solely for personal, non-commercial media enjoyment.

2. FAIR USE & COPYRIGHT RESPECT
• MozeMusic provides a modern client interface to stream audio indexed from publicly accessible platforms.
• Users agree to respect intellectual property rights and artist copyrights. Commercial redistribution or mass rebroadcasting of downloaded content is prohibited.

3. JAM ROOM CODE OF CONDUCT
When participating in collaborative Jam Rooms or public listening sessions, users agree not to inject malicious links, engage in disruptive spamming, or abuse real-time synchronization channels.

4. DISCLAIMER OF WARRANTIES
The software is provided ""AS IS"" without warranty of any kind. MozeMusic disclaims all implied warranties of merchantability, fitness for a particular purpose, and non-infringement.

5. BINDING CONSENT
By clicking ""I Agree"" and proceeding with this installation, you enter into a legally binding agreement with MozeMusic.";
#else
            rtbTerms.Text =
@"MOZEMUSIC SON KULLANICI LİSANS SÖZLEŞMESİ VE KULLANIM ŞARTLARI

1. LİSANS KAPSAMI
MozeMusic; uygulamanın kişisel, ticari olmayan müzik dinleme ve arşivleme amacıyla kullanılması için kullanıcıya geri alınabilir, münhasır olmayan bir kullanım lisansı sunar.

2. ADİL KULLANIM VE TELİF HAKLARINA SAYGI
• MozeMusic, herkese açık platformlar üzerinden yüksek performanslı bir dinleme ve arayüz deneyimi sağlar.
• Kullanıcılar sanatçıların ve telif hakkı sahiplerinin haklarına saygı göstermekle yükümlüdür. İndirilen parçaların ticari amaçla yeniden dağıtılması veya satılması yasaktır.

3. JAM ROOM VE TOPLULUK KURALLARI
Ortak müzik odalarında veya paylaşımlı listelerde diğer kullanıcıları rahatsız edici, zararlı veya spam niteliğinde eylemlerde bulunulamaz.

4. SORUMLULUK REDDİ
Yazılım ""OLDUĞU GİBİ"" (AS-IS) sağlanmaktadır. Sağlayıcı ağlarındaki dönemsel kesintilerden veya üçüncü taraf içerik değişikliklerinden MozeMusic sorumlu tutulamaz.

5. ONAY VE BAĞLAYICILIK
Aşağıdaki onay kutusunu işaretleyerek Kullanıcı Sözleşmesini, Gizlilik Politikasını ve Uygulama İzinlerini kabul etmiş sayılırsınız.";
#endif

            chkAgree = new CheckBox
            {
#if LANG_EN
                Text = "I have read, understood, and accept the User Agreement, Privacy Policy, and Permissions.",
#else
                Text = "Kullanıcı Sözleşmesini, Gizlilik Politikasını ve Uygulama İzinlerini okudum, anladım ve onaylıyorum.",
#endif
                ForeColor = ColText,
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                Location = new Point(0, 350),
                Size = new Size(560, 36),
                Cursor = Cursors.Hand
            };
            chkAgree.CheckedChanged += (s, e) =>
            {
                UpdateNextButtonState();
            };

            pnlStep4.Controls.Add(lblHeading);
            pnlStep4.Controls.Add(lblSub);
            pnlStep4.Controls.Add(rtbTerms);
            pnlStep4.Controls.Add(chkAgree);
            pnlContent.Controls.Add(pnlStep4);
        }

        // STEP 5: Installation Preferences (Path & Shortcuts)
        private void BuildStep5()
        {
            pnlStep5 = new Panel { Dock = DockStyle.Fill, Visible = false };

            Label lblHeading = new Label
            {
#if LANG_EN
                Text = "Installation Preferences",
#else
                Text = "Kurulum Tercihleri",
#endif
                Font = new Font("Segoe UI", 18f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 0),
                AutoSize = true
            };

            Label lblSub = new Label
            {
#if LANG_EN
                Text = "Choose destination directory and shortcut options for MozeMusic.",
#else
                Text = "Uygulamanın kurulacağı klasörü ve oluşturulacak kısayolları belirleyin.",
#endif
                Font = new Font("Segoe UI", 10f),
                ForeColor = ColTextMuted,
                Location = new Point(2, 36),
                AutoSize = true
            };

            // Folder section
            Label lblFolder = new Label
            {
#if LANG_EN
                Text = "Destination Folder:",
#else
                Text = "Kurulum Dizini:",
#endif
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 84),
                AutoSize = true
            };

            string defaultPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "MozeMusic");

            txtInstallPath = new TextBox
            {
                Text = defaultPath,
                Location = new Point(0, 110),
                Size = new Size(440, 32),
                Font = new Font("Segoe UI", 10f),
                BackColor = ColCard,
                ForeColor = ColText,
                BorderStyle = BorderStyle.FixedSingle
            };

#if LANG_EN
            Button btnBrowse = CreateStyledButton("Browse...", 100, false);
#else
            Button btnBrowse = CreateStyledButton("Gözat...", 100, false);
#endif
            btnBrowse.Location = new Point(454, 108);
            btnBrowse.Click += (s, e) =>
            {
                using (FolderBrowserDialog fbd = new FolderBrowserDialog())
                {
#if LANG_EN
                    fbd.Description = "Select installation folder for MozeMusic:";
#else
                    fbd.Description = "MozeMusic'in kurulacağı klasörü seçin:";
#endif
                    fbd.SelectedPath = txtInstallPath.Text;
                    if (fbd.ShowDialog() == DialogResult.OK)
                    {
                        txtInstallPath.Text = Path.Combine(fbd.SelectedPath, "MozeMusic");
                    }
                }
            };

            // Shortcuts section
            Label lblShortcuts = new Label
            {
#if LANG_EN
                Text = "Shortcut Preferences:",
#else
                Text = "Kısayol Seçenekleri:",
#endif
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 175),
                AutoSize = true
            };

            chkDesktopShortcut = new CheckBox
            {
#if LANG_EN
                Text = "Create a desktop shortcut for MozeMusic",
#else
                Text = "Masaüstünde MozeMusic kısayolu oluştur",
#endif
                Checked = true,
                ForeColor = ColText,
                Font = new Font("Segoe UI", 10f),
                Location = new Point(4, 205),
                Size = new Size(480, 26),
                Cursor = Cursors.Hand
            };

            chkStartMenuShortcut = new CheckBox
            {
#if LANG_EN
                Text = "Add MozeMusic to the Windows Start Menu",
#else
                Text = "Başlat Menüsüne MozeMusic program kısayolu ekle",
#endif
                Checked = true,
                ForeColor = ColText,
                Font = new Font("Segoe UI", 10f),
                Location = new Point(4, 238),
                Size = new Size(480, 26),
                Cursor = Cursors.Hand
            };

            pnlStep5.Controls.Add(lblHeading);
            pnlStep5.Controls.Add(lblSub);
            pnlStep5.Controls.Add(lblFolder);
            pnlStep5.Controls.Add(txtInstallPath);
            pnlStep5.Controls.Add(btnBrowse);
            pnlStep5.Controls.Add(lblShortcuts);
            pnlStep5.Controls.Add(chkDesktopShortcut);
            pnlStep5.Controls.Add(chkStartMenuShortcut);
            pnlContent.Controls.Add(pnlStep5);
        }

        // STEP 6: Installing Progress
        private void BuildStep6()
        {
            pnlStep6 = new Panel { Dock = DockStyle.Fill, Visible = false };

            Label lblHeading = new Label
            {
#if LANG_EN
                Text = "Installing MozeMusic",
#else
                Text = "MozeMusic Kuruluyor",
#endif
                Font = new Font("Segoe UI", 18f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(0, 0),
                AutoSize = true
            };

            lblInstallStatus = new Label
            {
#if LANG_EN
                Text = "Preparing installation package and binaries...",
#else
                Text = "Kurulum paketi hazırlanıyor ve bileşenler taranıyor...",
#endif
                Font = new Font("Segoe UI", 10f),
                ForeColor = ColTextMuted,
                Location = new Point(2, 38),
                Size = new Size(540, 24)
            };

            progressBar = new SmoothProgressBar
            {
                Location = new Point(0, 110),
                Size = new Size(560, 24),
                BackColor = ColCard,
                ForeColor = ColAccent,
                Value = 0
            };

            lblInstallDetail = new Label
            {
#if LANG_EN
                Text = "Please wait while files are being copied to your system.",
#else
                Text = "Lütfen kurulum işlemi tamamlanana kadar bekleyin.",
#endif
                Font = new Font("Segoe UI", 9f),
                ForeColor = ColTextDisabled,
                Location = new Point(2, 145),
                Size = new Size(560, 24)
            };

            pnlStep6.Controls.Add(lblHeading);
            pnlStep6.Controls.Add(lblInstallStatus);
            pnlStep6.Controls.Add(progressBar);
            pnlStep6.Controls.Add(lblInstallDetail);
            pnlContent.Controls.Add(pnlStep6);
        }

        // STEP 7: Completed
        private void BuildStep7()
        {
            pnlStep7 = new Panel { Dock = DockStyle.Fill, Visible = false };

            Label lblBadge = new Label
            {
                Text = "✓",
                Font = new Font("Segoe UI", 28f, FontStyle.Bold),
                ForeColor = ColStepDone,
                Location = new Point(0, 10),
                Size = new Size(60, 60),
                TextAlign = ContentAlignment.MiddleCenter
            };

            Label lblHeading = new Label
            {
#if LANG_EN
                Text = "Installation Completed Successfully!",
#else
                Text = "Kurulum Başarıyla Tamamlandı!",
#endif
                Font = new Font("Segoe UI", 18f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(70, 18),
                AutoSize = true
            };

            Label lblSub = new Label
            {
#if LANG_EN
                Text = "MozeMusic has been installed on your PC.\nYou are ready to enjoy unlimited high-fidelity music.",
#else
                Text = "MozeMusic bilgisayarınıza sorunsuz bir şekilde yüklendi.\nArtık sınırsız ve kaliteli müziğin tadını çıkarabilirsiniz.",
#endif
                Font = new Font("Segoe UI", 10.5f),
                ForeColor = ColTextMuted,
                Location = new Point(70, 56),
                Size = new Size(480, 48)
            };

            Panel cardDone = new Panel
            {
                Location = new Point(0, 125),
                Size = new Size(560, 160),
                BackColor = ColCard
            };
            cardDone.Paint += (s, e) =>
            {
                using (Pen p = new Pen(ColCardBorder, 1))
                {
                    e.Graphics.DrawRectangle(p, 0, 0, cardDone.Width - 1, cardDone.Height - 1);
                }
            };

            chkLaunchApp = new CheckBox
            {
#if LANG_EN
                Text = "Launch MozeMusic now",
#else
                Text = "MozeMusic uygulamasını şimdi başlat",
#endif
                Checked = true,
                Font = new Font("Segoe UI", 11f, FontStyle.Bold),
                ForeColor = ColText,
                Location = new Point(20, 24),
                Size = new Size(480, 28),
                Cursor = Cursors.Hand
            };

            Label lblHint = new Label
            {
#if LANG_EN
                Text = "You can launch the app anytime via the desktop icon or the Windows Start Menu. Enjoy your tunes!",
#else
                Text = "Masaüstünüzde ve Başlat Menünüzde oluşturulan MozeMusic simgesine tıklayarak uygulamaya dilediğiniz zaman erişebilirsiniz.",
#endif
                Font = new Font("Segoe UI", 9.5f),
                ForeColor = ColTextMuted,
                Location = new Point(20, 64),
                Size = new Size(500, 60)
            };

            cardDone.Controls.Add(chkLaunchApp);
            cardDone.Controls.Add(lblHint);

            pnlStep7.Controls.Add(lblBadge);
            pnlStep7.Controls.Add(lblHeading);
            pnlStep7.Controls.Add(lblSub);
            pnlStep7.Controls.Add(cardDone);
            pnlContent.Controls.Add(pnlStep7);
        }

        #endregion

        #region Navigation & Wizard Logic

        private void ShowStep(int step)
        {
            currentStep = step;

            pnlStep1.Visible = (step == 1);
            pnlStep2.Visible = (step == 2);
            pnlStep3.Visible = (step == 3);
            pnlStep4.Visible = (step == 4);
            pnlStep5.Visible = (step == 5);
            pnlStep6.Visible = (step == 6);
            pnlStep7.Visible = (step == 7);

            btnBack.Visible = (step > 1 && step < 6);
            btnCancel.Visible = (step < 6);

#if LANG_EN
            if (step == 1)
            {
                btnNext.Text = "Next >";
                btnNext.Enabled = true;
            }
            else if (step == 2)
            {
                btnNext.Text = "Next >";
                btnNext.Enabled = true;
            }
            else if (step == 3)
            {
                btnNext.Text = "Next >";
                btnNext.Enabled = true;
            }
            else if (step == 4)
            {
                btnNext.Text = "Agree & Next >";
                UpdateNextButtonState();
            }
            else if (step == 5)
            {
                btnNext.Text = "Install Now";
                btnNext.Enabled = true;
            }
            else if (step == 6)
            {
                btnNext.Visible = false;
            }
            else if (step == 7)
            {
                btnNext.Visible = true;
                btnNext.Text = "Finish";
                btnNext.Enabled = true;
            }
#else
            if (step == 1)
            {
                btnNext.Text = "İleri >";
                btnNext.Enabled = true;
            }
            else if (step == 2)
            {
                btnNext.Text = "İleri >";
                btnNext.Enabled = true;
            }
            else if (step == 3)
            {
                btnNext.Text = "İleri >";
                btnNext.Enabled = true;
            }
            else if (step == 4)
            {
                btnNext.Text = "Kabul Et ve İleri >";
                UpdateNextButtonState();
            }
            else if (step == 5)
            {
                btnNext.Text = "Kurulumu Başlat";
                btnNext.Enabled = true;
            }
            else if (step == 6)
            {
                btnNext.Visible = false;
            }
            else if (step == 7)
            {
                btnNext.Visible = true;
                btnNext.Text = "Bitir";
                btnNext.Enabled = true;
            }
#endif

            pnlSidebar.Invalidate();
        }

        private void UpdateNextButtonState()
        {
            if (currentStep == 4)
            {
                bool agreed = chkAgree != null && chkAgree.Checked;
                btnNext.Enabled = agreed;
                btnNext.BackColor = agreed ? ColAccent : ColAccentDisabled;
                btnNext.ForeColor = agreed ? Color.White : ColTextDisabled;
            }
        }

        private void BtnNext_Click(object sender, EventArgs e)
        {
            if (currentStep == 1)
            {
                ShowStep(2);
            }
            else if (currentStep == 2)
            {
                ShowStep(3);
            }
            else if (currentStep == 3)
            {
                ShowStep(4);
            }
            else if (currentStep == 4)
            {
                if (chkAgree.Checked)
                {
                    ShowStep(5);
                }
            }
            else if (currentStep == 5)
            {
                ShowStep(6);
                StartInstallation();
            }
            else if (currentStep == 7)
            {
                if (chkLaunchApp.Checked)
                {
                    string targetExe = Path.Combine(txtInstallPath.Text, "mozemusic.exe");
                    if (File.Exists(targetExe))
                    {
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = targetExe,
                            WorkingDirectory = txtInstallPath.Text
                        });
                    }
                }
                this.Close();
            }
        }

        private void StartInstallation()
        {
            string installDir = txtInstallPath.Text.Trim();
            bool makeDesktop = chkDesktopShortcut.Checked;
            bool makeStartMenu = chkStartMenuShortcut.Checked;

            Thread worker = new Thread(() =>
            {
                try
                {
#if LANG_EN
                    UpdateProgress(5, "Preparing target installation directory...", installDir);
#else
                    UpdateProgress(5, "Kurulum dizini hazırlanıyor...", installDir);
#endif
                    Directory.CreateDirectory(installDir);
                    Thread.Sleep(300);

                    // Extract embedded resource
                    Assembly asm = Assembly.GetExecutingAssembly();
                    Stream resStream = asm.GetManifestResourceStream("MozeMusicPayload");

                    if (resStream != null)
                    {
                        using (resStream)
                        using (ZipArchive archive = new ZipArchive(resStream))
                        {
                            int total = archive.Entries.Count;
                            int count = 0;

                            foreach (ZipArchiveEntry entry in archive.Entries)
                            {
                                count++;
                                string destPath = Path.Combine(installDir, entry.FullName);

                                if (string.IsNullOrEmpty(entry.Name))
                                {
                                    Directory.CreateDirectory(destPath);
                                }
                                else
                                {
                                    Directory.CreateDirectory(Path.GetDirectoryName(destPath));
                                    entry.ExtractToFile(destPath, true);
                                }

                                int percent = 10 + (int)((count / (double)total) * 75);
#if LANG_EN
                                UpdateProgress(percent, "Extracting application components...", entry.Name);
#else
                                UpdateProgress(percent, "Dosyalar çıkartılıyor...", entry.Name);
#endif
                                Thread.Sleep(8);
                            }
                        }
                    }
                    else
                    {
                        // Fallback: copy from source Release build if available
                        string fallbackSource = @"D:\src\mozemusic\build\windows\x64\runner\Release";
                        if (Directory.Exists(fallbackSource))
                        {
                            CopyDirectory(fallbackSource, installDir);
                        }
                    }

#if LANG_EN
                    UpdateProgress(90, "Creating Windows shortcuts...", "Desktop and Start Menu");
#else
                    UpdateProgress(90, "Kısayollar oluşturuluyor...", "Masaüstü ve Başlat Menüsü");
#endif
                    Thread.Sleep(300);

                    string targetExe = Path.Combine(installDir, "mozemusic.exe");

                    if (makeDesktop)
                    {
                        string desktopPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "MozeMusic.lnk");
                        CreateShortcut(desktopPath, targetExe, installDir, "MozeMusic Desktop Application");
                    }

                    if (makeStartMenu)
                    {
                        string startMenuPrograms = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
                        string startMenuShortcut = Path.Combine(startMenuPrograms, "MozeMusic.lnk");
                        CreateShortcut(startMenuShortcut, targetExe, installDir, "MozeMusic Music App");
                    }

#if LANG_EN
                    UpdateProgress(100, "Installation complete!", "Ready to launch.");
#else
                    UpdateProgress(100, "Kurulum tamamlandı!", "Tüm bileşenler hazır.");
#endif
                    Thread.Sleep(500);

                    this.Invoke(new Action(() => ShowStep(7)));
                }
                catch (Exception ex)
                {
                    this.Invoke(new Action(() =>
                    {
#if LANG_EN
                        MessageBox.Show("An error occurred during installation:\n" + ex.Message, "Installation Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
#else
                        MessageBox.Show("Kurulum sırasında bir hata oluştu:\n" + ex.Message, "Kurulum Hatası", MessageBoxButtons.OK, MessageBoxIcon.Error);
#endif
                        ShowStep(5);
                    }));
                }
            });

            worker.IsBackground = true;
            worker.Start();
        }

        private void CopyDirectory(string sourceDir, string destDir)
        {
            string[] allFiles = Directory.GetFiles(sourceDir, "*.*", SearchOption.AllDirectories);
            int count = 0;
            foreach (string file in allFiles)
            {
                count++;
                string relative = file.Substring(sourceDir.Length).TrimStart('\\', '/');
                string target = Path.Combine(destDir, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                File.Copy(file, target, true);

                int percent = 10 + (int)((count / (double)allFiles.Length) * 75);
#if LANG_EN
                UpdateProgress(percent, "Copying application binaries...", Path.GetFileName(file));
#else
                UpdateProgress(percent, "Dosyalar kopyalanıyor...", Path.GetFileName(file));
#endif
                Thread.Sleep(10);
            }
        }

        private void CreateShortcut(string shortcutPath, string targetPath, string workingDir, string description)
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType != null)
                {
                    dynamic shell = Activator.CreateInstance(shellType);
                    dynamic shortcut = shell.CreateShortcut(shortcutPath);
                    shortcut.TargetPath = targetPath;
                    shortcut.WorkingDirectory = workingDir;
                    shortcut.Description = description;
                    shortcut.IconLocation = targetPath + ",0";
                    shortcut.Save();
                }
            }
            catch { }
        }

        private void UpdateProgress(int percent, string status, string detail)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => UpdateProgress(percent, status, detail)));
                return;
            }

            progressBar.Value = Math.Min(100, Math.Max(0, percent));
            lblInstallStatus.Text = status;
            lblInstallDetail.Text = detail;
        }

        private bool ConfirmExit()
        {
            if (currentStep == 7) return true;
#if LANG_EN
            return MessageBox.Show("Are you sure you want to cancel MozeMusic installation?", "Cancel Setup", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;
#else
            return MessageBox.Show("MozeMusic kurulumundan çıkmak istediğinize emin misiniz?", "Kurulumu İptal Et", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;
#endif
        }

        #endregion

        #region Custom Painting & Sidebar

        private void Sidebar_Paint(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            // Brand Header
            int logoY = 20;
            using (SolidBrush b = new SolidBrush(ColAccent))
            {
                FillRoundedRectangle(g, b, new Rectangle(24, logoY, 40, 40), 10);
            }

            using (Font fIcon = new Font("Segoe UI", 16f, FontStyle.Bold))
            using (SolidBrush bWhite = new SolidBrush(Color.White))
            {
                g.DrawString("M", fIcon, bWhite, 34, logoY + 7);
            }

            using (Font fBrand = new Font("Segoe UI", 13f, FontStyle.Bold))
            using (SolidBrush bText = new SolidBrush(ColText))
            {
                g.DrawString("MozeMusic", fBrand, bText, 72, logoY + 4);
            }

            using (Font fSub = new Font("Segoe UI", 8.5f))
            using (SolidBrush bMuted = new SolidBrush(ColTextMuted))
            {
#if LANG_EN
                g.DrawString("Setup Wizard", fSub, bMuted, 74, logoY + 24);
#else
                g.DrawString("Kurulum Sihirbazı", fSub, bMuted, 74, logoY + 24);
#endif
            }

            // Divider
            using (Pen p = new Pen(ColCardBorder, 1))
            {
                g.DrawLine(p, 20, 74, pnlSidebar.Width - 20, 74);
            }

            // Steps
#if LANG_EN
            string[] stepTitles = {
                "Welcome",
                "Permissions",
                "Privacy Policy",
                "Terms of Service",
                "Preferences",
                "Installing",
                "Completed"
            };
#else
            string[] stepTitles = {
                "Hoş Geldiniz",
                "İzinler",
                "Gizlilik Politikası",
                "Kullanıcı Şartları",
                "Tercihler",
                "Yükleniyor",
                "Tamamlandı"
            };
#endif

            int stepStartY = 92;
            int stepGap = 42;

            for (int i = 0; i < TotalSteps; i++)
            {
                int stepNum = i + 1;
                int cy = stepStartY + (i * stepGap);

                bool isCurrent = (stepNum == currentStep);
                bool isPast = (stepNum < currentStep);

                // Indicator circle
                Color circleCol = isCurrent ? ColStepActive : (isPast ? ColStepDone : ColCardBorder);
                using (SolidBrush bCircle = new SolidBrush(circleCol))
                {
                    g.FillEllipse(bCircle, 24, cy, 22, 22);
                }

                // Inner text or checkmark
                string glyph = isPast ? "✓" : stepNum.ToString();
                using (Font fGlyph = new Font("Segoe UI", 8.5f, FontStyle.Bold))
                using (SolidBrush bGlyph = new SolidBrush(Color.White))
                {
                    int gx = isPast ? 28 : 31;
                    g.DrawString(glyph, fGlyph, bGlyph, gx, cy + 3);
                }

                // Step label
                Color textCol = isCurrent ? ColText : (isPast ? ColTextMuted : ColTextDisabled);
                using (Font fStep = new Font("Segoe UI", 9.5f, isCurrent ? FontStyle.Bold : FontStyle.Regular))
                using (SolidBrush bStep = new SolidBrush(textCol))
                {
                    g.DrawString(stepTitles[i], fStep, bStep, 56, cy + 2);
                }

                // Connecting line
                if (i < TotalSteps - 1)
                {
                    using (Pen pLine = new Pen(isPast ? ColStepDone : ColCardBorder, 2))
                    {
                        g.DrawLine(pLine, 35, cy + 23, 35, cy + stepGap - 1);
                    }
                }
            }

            // Divider above Powered By
            using (Pen p = new Pen(ColCardBorder, 1))
            {
                g.DrawLine(p, 20, 514, pnlSidebar.Width - 20, 514);
            }
        }

        private void FillRoundedRectangle(Graphics g, Brush b, Rectangle rect, int radius)
        {
            using (GraphicsPath path = new GraphicsPath())
            {
                path.AddArc(rect.X, rect.Y, radius * 2, radius * 2, 180, 90);
                path.AddArc(rect.Right - (radius * 2), rect.Y, radius * 2, radius * 2, 270, 90);
                path.AddArc(rect.Right - (radius * 2), rect.Bottom - (radius * 2), radius * 2, radius * 2, 0, 90);
                path.AddArc(rect.X, rect.Bottom - (radius * 2), radius * 2, radius * 2, 90, 90);
                path.CloseFigure();
                g.FillPath(b, path);
            }
        }

        #endregion

        #region Window Dragging

        private void Title_MouseDown(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                isDragging = true;
                dragCursorPoint = Cursor.Position;
                dragFormPoint = this.Location;
            }
        }

        private void Title_MouseMove(object sender, MouseEventArgs e)
        {
            if (isDragging)
            {
                Point diff = Point.Subtract(Cursor.Position, new Size(dragCursorPoint));
                this.Location = Point.Add(dragFormPoint, new Size(diff));
            }
        }

        private void Title_MouseUp(object sender, MouseEventArgs e)
        {
            isDragging = false;
        }

        #endregion
    }

    public class SmoothProgressBar : Control
    {
        private int _value = 0;

        public int Value
        {
            get { return _value; }
            set
            {
                _value = Math.Min(100, Math.Max(0, value));
                Invalidate();
            }
        }

        public SmoothProgressBar()
        {
            this.SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            // Background
            using (SolidBrush bBg = new SolidBrush(this.BackColor))
            {
                g.FillRectangle(bBg, 0, 0, this.Width, this.Height);
            }

            // Fill
            if (_value > 0)
            {
                int fillWidth = (int)((_value / 100.0) * this.Width);
                using (SolidBrush bFill = new SolidBrush(this.ForeColor))
                {
                    g.FillRectangle(bFill, 0, 0, fillWidth, this.Height);
                }
            }

            // Border
            using (Pen p = new Pen(Color.FromArgb(50, 50, 60), 1))
            {
                g.DrawRectangle(p, 0, 0, this.Width - 1, this.Height - 1);
            }
        }
    }
}
