# Toragram (仮) - 店舗応援・ナレッジ共有プラットフォーム

店舗スタッフ間での売り場作りの成功事例や、日々の業務・ナレッジを共有するためのSNSアプリケーションです。「良い売り場を真似する（横展開する）」文化の醸成を目的としています。

![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=flat&logo=flutter)
![Node.js](https://img.shields.io/badge/Node.js-Express-339933?style=flat&logo=node.js)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Prisma-336791?style=flat&logo=postgresql)
![Firebase](https://img.shields.io/badge/Auth-Firebase-FFCA28?style=flat&logo=firebase)
![Render](https://img.shields.io/badge/Deploy-Render-46E3B7?style=flat&logo=render)

## 📖 プロジェクト概要

### 目的
* 店舗応援期間中における売り場陳列の成功事例共有
* 従業員間のコミュニケーション活性化
* 「いいね」や「真似したい」によるモチベーション向上とナレッジ蓄積

### システム構成
* **Frontend:** Flutter (Web)
* **Backend:** Node.js (Express) + TypeScript
* **Database:** PostgreSQL (via Prisma ORM)
* **Auth:** Firebase Authentication
* **Storage:** Cloudinary (画像ホスティング)
* **Infra:** Render (Web Service + PostgreSQL)

---

## 🛠 機能要件 (Functional Requirements)

### 1. ユーザー認証・設定
* **ログイン:** Firebase Authを使用したメール/パスワード認証
* **プロフィール:** 表示名、興味のあるカテゴリー（フィルタリング用）の設定
* **設定保存:** 自分の投稿の表示/非表示設定（端末ローカル保存 / Shared Preferences）

### 2. タイムライン表示
* **タブ切り替え:**
    * **おすすめ:** 全投稿、または興味のあるカテゴリーに基づく投稿
    * **店舗:** 店舗に関する投稿のみをフィルタリング
    * **フォロー中:** フォローユーザーの投稿（未読バッジ機能付き）
* **カード表示:** 投稿画像、投稿者情報、本文、リアクション数

### 3. 投稿機能
* **メディア:** 画像アップロード（Cloudinary連携）
* **情報入力:** テキスト本文、カテゴリー選択（グロサリー、飲料、日配など）
* **UI/UX:** キーボード表示時のレイアウト調整、レスポンシブ対応

### 4. リアクション・評価システム
* **いいね (Like):** 共感の意思表示
* **真似したい (Mimic):** 「自店でも実施したい」という意思表示（ランキングの重要指標）

### 5. ランキング機能
* **集計期間:** 週間 / 月間
* **表示:** 上位3位へのバッジ表示、人気投稿の可視化

---

## 🏗 システムアーキテクチャ & 設計

### ディレクトリ構成 (Monorepo構成)

```text
/
├── backend/          # Node.js + Express + Prisma
│   ├── prisma/       # DB Schema (schema.prisma)
│   ├── src/
│   │   ├── controllers/
│   │   ├── routes/
│   │   └── services/
│   └── ...
│
└── frontend/         # Flutter Web App
    ├── lib/
    │   ├── models/
    │   ├── screens/
    │   ├── services/ # API Connect
    │   └── widgets/
    └── ...
```
### ER図
```mermaid
erDiagram
    %% User and Post Relationship
    User ||--o{ Post : "writes (1:N)"
    
    %% Reactions
    User ||--o{ Like : "gives (1:N)"
    Post ||--o{ Like : "receives (1:N)"
    
    User ||--o{ Mimic : "gives (1:N)"
    Post ||--o{ Mimic : "receives (1:N)"

    User {
        String id PK "Firebase UID"
        String email
        String displayName
        String[] interestedCategories "Filter settings"
        DateTime createdAt
    }

    Post {
        Int id PK
        String userId FK
        String content
        String imageUrl "Cloudinary URL"
        String category
        DateTime createdAt
    }

    Like {
        Int id PK
        String userId FK
        Int postId FK
        DateTime createdAt
    }

    Mimic {
        Int id PK
        String userId FK
        Int postId FK
        DateTime createdAt
    }
```

### 画面遷移図
```mermaid
graph TD
    %% --- 初期起動フロー ---
    Start((アプリ起動)) --> Login[LoginScreen]

    %% --- 認証・登録グループ ---
    subgraph Auth [認証・登録]
        %% ログイン後の条件分岐 (_navigateAfterLogin)
        Login -->|カテゴリー設定済| Main[MainScreen]
        Login -->|カテゴリー未設定| CategorySel[CategorySelectionScreen]
        
        %% 新規登録フロー
        Login -->|"未登録IDスキャン / 新規登録ボタン"| Signup[SignupScreen]
        Signup --> CategorySel
        CategorySel --> Main
    end

    %% --- メインナビゲーション (MainScreen管理) ---
    subgraph AppShell [メイン機能]
        Main -->|"Tab 1"| Home[HomeScreen]
        Main -->|"Tab 2"| Ranking[RankingScreen]
        Main -->|"Tab 3"| Scanner[ScannerScreen]
        Main -->|"Tab 4"| MyProfile["ProfileScreen:自分"]
    end

    %% --- 機能詳細フロー ---
    subgraph Actions [詳細・アクション]
        %% 投稿関連
        Home -->|FAB| Create[CreatePostScreen]
        Home -->|検索| Search[SearchScreen]
        Home -->|詳細| PostDetail[PostDetailScreen]
        Ranking -->|詳細| PostDetail
        
        %% 編集・削除
        PostDetail -->|"編集(自分)"| EditPost[EditPostScreen]

        %% プロフィール・ユーザー関連
        Home -->|アイコンタップ| UserProfile["ProfileScreen:他ユーザー"]
        Ranking -->|アイコンタップ| UserProfile
        
        %% プロフィール内部のアクション
        MyProfile -->|編集| EditProfile[EditProfileScreen]
        MyProfile -->|"フォロー/フォロワー"| UserList[UserListScreen]
        MyProfile -->|真似した投稿| Copied[CopiedPostsScreen]
        
        UserProfile -->|"フォロー/フォロワー"| UserList
    end

    %% --- スタイル定義 ---
    classDef main fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    classDef auth fill:#fff3e0,stroke:#e65100,stroke-width:2px;
    class Main,Home,Ranking,MyProfile,Scanner main;
    class Login,Signup,CategorySel auth;
```
