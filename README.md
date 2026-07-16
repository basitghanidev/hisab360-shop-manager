# Shop Manager 📋

A professional, offline-first Point of Sale (POS) and Khata management system built with Flutter. Designed for retailers to manage inventory, sales, purchases, and complex customer/supplier credit (Khata) with precision.

[![Flutter](https://img.shields.io/badge/Flutter-v3.22+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean_Architecture-green)](#architecture)
[![Database](https://img.shields.io/badge/Database-Drift_(SQLite)-orange)](https://drift.simonbinder.eu/)
[![State Management](https://img.shields.io/badge/State-Riverpod-764ABC)](https://riverpod.dev/)

---

## 🚀 Key Features

### 🛒 Sales & Inventory
- **Multi-Type Invoicing:** Supports Retail (Parchoon) and Wholesale (Thok) sales.
- **Stock Integrity:** Real-time stock tracking with zero-stock prevention and automatic low-stock alerts.
- **Batch Tracking:** FIFO and Average Costing methods for accurate profit calculation.

### 💳 Khata & Debt Management
- **360° Financial View:** Manage Suppliers, Wholesalers, and Customers in one place.
- **Bilingual Ledgers:** Clear English/Roman-Urdu labels (Wasooli, Adaigi) for better accessibility.
- **Refund Logic:** Handles returns with immediate cash refunds or credit adjustments automatically.

### 📊 Reporting & Analytics
- **Dynamic Reports:** Monthly and Yearly breakdowns of sales, profit, and cash flow.
- **PDF Generation:** Professional A4 and Thermal (80mm/58mm) receipt printing.
- **ACID Compliant:** All financial transactions are wrapped in database transactions to ensure 100% data integrity.

---

## 🛠 Tech Stack

- **Framework:** [Flutter](https://flutter.dev) (UI/UX)
- **State Management:** [Riverpod](https://riverpod.dev) (Functional & Reactive)
- **Local Database:** [Drift (SQLite)](https://drift.simonbinder.eu) (Type-safe persistent storage)
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router) (Declarative routing)
- **PDF Engine:** [Printing](https://pub.dev/packages/printing) & [PDF](https://pub.dev/packages/pdf)
- **Dependency Injection:** Riverpod Providers

---

## 🏗 Architecture

The project follows a **Feature-based Clean Architecture** to ensure scalability and maintainability:

```text
lib/
├── core/               # Shared logic (database, services, constants, themes)
│   ├── database/       # Drift tables and DAOs
│   ├── services/       # PDF, Backup, and Ledger logic
│   └── widgets/        # Reusable UI components (AppCard, BilingualLabel)
├── features/           # Modular features
│   ├── dashboard/      # Home stats & Khata summary
│   ├── invoices/       # Sales and Purchase logic
│   ├── items/          # Inventory management
│   ├── people/         # Customer & Supplier profiles
│   └── ...             # Settings, Backup, Returns
└── router/             # GoRouter configuration
```

---

## 🧪 Quality Assurance

Built with a "Production-First" mindset:
- **Unit Testing:** 25+ tests covering Money precision, Ledger balance math, and Invoice calculations.
- **Atomic Transactions:** Every payment and return is executed as a single unit—if one part fails, nothing is saved.
- **Static Analysis:** Strict linting rules to ensure clean, performant code.

---

## 🛠 Getting Started

### Prerequisites
- Flutter SDK v3.22 or higher
- Dart v3.4 or higher

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/basitghanidev/hisab360-shop-manager.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Generate database code (Drift):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
4. Run the app:
   ```bash
   flutter run
   ```

---

## 🌐 Web Deployment (Vercel)

You can host **Hisab360** on Vercel for free:
1. Connect your GitHub repository to [Vercel](https://vercel.com).
2. Vercel will automatically detect the `package.json`.
3. Use the following settings:
   - **Framework Preset:** Other
   - **Build Command:** `npm run build`
   - **Output Directory:** `build/web`
4. Deploy! Your app will be live at `your-project.vercel.app`.

---

## 👤 Author

**Basit Ghani**
- LinkedIn:  https://www.linkedin.com/in/basitghanidev/
   
---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
