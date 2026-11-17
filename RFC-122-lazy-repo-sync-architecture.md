# Uyuni RFC #122: Lazy Repository Synchronization — Architecture

Reference: [uyuni-project/uyuni-rfc PR #122](https://github.com/uyuni-project/uyuni-rfc/pull/122)

---

## 1. Architecture Diagram

```mermaid
flowchart TB
    %% Styling Definitions
    classDef newComp fill:#1b4d3e,stroke:#2ecc71,stroke-width:2px,color:#ffffff;
    classDef changedComp fill:#4a3500,stroke:#f39c12,stroke-width:2px,color:#ffffff;
    classDef existComp fill:#1c2833,stroke:#7f8c8d,stroke-width:1px,color:#ffffff;
    classDef storage fill:#1a365d,stroke:#3182ce,stroke-width:2px,color:#ffffff;
    classDef external fill:#2d3748,stroke:#a0aec0,stroke-width:1px,stroke-dasharray: 4 4,color:#ffffff;

    subgraph CLIENTS ["Clients & Minions"]
        MINION["Salt Minions / Clients\n(Zypper / DNF / YUM)"]:::existComp
        UPROXY["Uyuni Proxy\n(Optional Cache / Accelerator)"]:::existComp
    end

    subgraph UPSTREAM ["Upstream Sources"]
        MIRROR["Upstream Repositories / CDN\n(SCC, openSUSE, RH CDN)"]:::external
        PROXY["Corporate HTTP Proxy\n(Optional)"]:::external
    end

    subgraph CONTROL_PLANE ["Uyuni Management & UI"]
        UI_API["Web UI / XML-RPC / REST API\n[CHANGED]\n- Manual Package Download Button\n- CLM Pre-Download Flags"]:::changedComp
        CLM["Content Lifecycle Mgmt (CLM)\n[CHANGED]\n- Pre-download trigger on Build/Promote"]:::changedComp
    end

    subgraph SYNC_PLANE ["Repository Sync Layer"]
        REPOSYNC["repo-sync-ng\n[NEW]\n- Metadata-only download\n- Evaluates Strategy (all/bootstrap/latest)\n- Assigns downloadPriority & relativePath"]:::newComp
        REPOMD_GEN["Taskomatic RepomdWriter\n[CHANGED]\n- Generates repomd.xml immediately\n- Instant channel/minion availability"]:::changedComp
    end

    subgraph PERSISTENCE ["Storage & Database"]
        DB[("PostgreSQL Database\n[CHANGED: rhnPackage]\n- downloadStatus (N, P, E, R)\n- downloadPriority (0-9)\n- downloadRelativePath\n- retry_count")]:::storage
        CACHE[("Local Package Cache\n[EXISTING]\n/var/spacewalk/packages/...")]:::storage
        LOCK_REG[("Locking & Concurrency Registry\n[NEW]\n- File / DB Advisory Locks\n- Global Concurrency Semaphore")]:::newComp
    end

    subgraph ASYNC_PULL ["Background Download Plane (Taskomatic)"]
        TASK_DL["Async Package Downloader\n[NEW Taskomatic Job]\n- Polls (P)ending packages by Priority\n- Acquires lock & verifies checksum\n- Saves to Cache & sets status = (R)eady"]:::newComp
    end

    subgraph SERVING_PLANE ["Serving & On-Demand Ingestion Plane"]
        APACHE["Apache HTTPD / Web Server\n[CHANGED]\nRouting & Request Interception"]:::changedComp
        
        subgraph ON_DEMAND_SERVICE ["On-Demand Download Endpoint (lazydownsuma) [NEW]"]
            GATEWAY["Request Interceptor\n& Cache Check"]:::newComp
            THROTTLE["Concurrency & Throttling Controller\n- Single Retrieval per Package\n- Max Concurrent Downloads\n- Max Waiting Clients"]:::newComp
            STREAMER["On-Demand Fetcher & Verifier\n- Fetches upstream to .tmp\n- Checksum Validation\n- Atomic Move to Cache"]:::newComp
        end
    end

    %% Sync & Control Interactions
    UI_API -->|Manual trigger| DB
    CLM -->|Flag environment packages| DB
    REPOSYNC -->|1. Fetch Metadata Only| MIRROR
    REPOSYNC -->|2. Populate Package/Errata metadata\n& Set Status=(P)ending, Priority| DB
    REPOSYNC -.->|3. Trigger Metadata Generation| REPOMD_GEN
    REPOMD_GEN -->|Generate Repo XMLs from DB| CACHE

    %% Async Background Download Flow
    TASK_DL -->|Poll (P)ending by Priority| DB
    TASK_DL <-->|Acquire/Release Lock| LOCK_REG
    TASK_DL -->|Fetch Package via Proxy/Direct| PROXY
    PROXY --> MIRROR
    TASK_DL -->|Atomic Move .tmp -> Permanent| CACHE
    TASK_DL -->|Update Status=(R)eady / Path| DB

    %% Client / Minion Request Flow
    MINION -->|HTTP GET Package| UPROXY
    UPROXY -->|Pass-through / Cache Miss| APACHE
    MINION -->|Direct HTTP GET Package| APACHE

    %% Serving & On-Demand Flow
    APACHE --> GATEWAY
    GATEWAY -->|Cache Hit (Exists on Disk)| CACHE
    CACHE -.->|Directly Stream to Client| APACHE
    
    GATEWAY -->|Cache Miss| THROTTLE
    THROTTLE <-->|Acquire Single-Package Lock\n& Global Permit| LOCK_REG
    THROTTLE -->|Delegate Download| STREAMER
    STREAMER -->|Fetch Package Payload| PROXY
    STREAMER -->|Checksum & Atomic Move| CACHE
    STREAMER -->|Update Status=(R)eady| DB
    STREAMER -.->|Signal Waiting Threads\n& Stream Payload| APACHE
    APACHE -->|HTTP 200 OK File Payload| MINION
```

---

## 2. Component Breakdown & Interaction Table

| Component | Status | Role & Architectural Changes |
| :--- | :--- | :--- |
| **`repo-sync-ng`** | **NEW** | Decouples metadata from package binaries. Fetches upstream `repomd`/indices only, inserts package and errata definitions into PostgreSQL, calculates `downloadRelativePath`, and applies the download strategy (`all`, `bootstrap`, `latest`) to assign `downloadPriority` (0–9) and set `downloadStatus = '(P)ending'`. Runs alongside legacy `repo-sync` until stabilized. |
| **`rhnPackage` Schema** | **CHANGED** | Extended with: `downloadStatus` (`(N)o Download`, `(P)ending`, `(E)rror`, `(R)eady`), `downloadPriority` (int `0-9`), `downloadRelativePath` (varchar), and `retry_count` (int). |
| **Async Package Downloader** | **NEW** | Quartz background task in Taskomatic. Queries `rhnPackage` for `(P)ending` packages ordered by priority, resolves upstream mirror URLs from `rhnContentSource`, downloads payload to temporary storage, validates checksum, commits to `/var/spacewalk/packages/...`, and marks record `(R)eady`. |
| **Repomd Generator** | **CHANGED** | `RepomdWriter` generates channel repodata directly from database records without requiring RPM files on disk, making channels and Content Lifecycle Management (CLM) immediately available. |
| **Pre-Download Enhancements** | **CHANGED** | - **UI & API:** Adds manual "Request Download" actions for individual packages.<br>- **CLM:** Build/Promote actions inspect environment channels and proactively set `downloadStatus = 'P'` for necessary packages. |
| **On-Demand Endpoint (`lazydownsuma`)** | **NEW** | Reverse-proxy/WSGI interceptor for client package requests (`/rhn/packages/...` or `/getPackage/...`):<br>1. **Cache Hit:** Serves immediately from disk via Apache acceleration.<br>2. **Cache Miss:** Throttles via single-package locking and global semaphore limits, downloads upstream to temporary file, verifies checksum, atomically renames to disk cache, updates DB, and streams back to waiting clients. |
| **Locking & Concurrency Registry** | **NEW** | Cross-process coordination mechanism (filesystem `flock` or PostgreSQL advisory locks) preventing duplicate upstream downloads between Taskomatic and on-demand web workers. |

---

## 3. Data Flow Summary

### A. Metadata Synchronization Flow
1. `repo-sync-ng` contacts upstream repository mirrors and downloads only repodata (`repomd.xml`, `primary.xml`, `updateinfo.xml`).
2. Packages and errata are inserted into database tables (`rhnPackage`, `rhnErrata`, `rhnChannelPackage`).
3. For each package, based on the channel strategy (`all`, `bootstrap`, `latest`), `downloadPriority` (0–9) and `downloadStatus` are assigned.
4. Channel metadata generation (`RepomdWriter`) is triggered, rendering the channel instantly available for client assignment and CLM projects.

### B. Asynchronous Pre-Download Flow (Taskomatic)
1. Taskomatic runs periodically, executing `SELECT ... FROM rhnPackage WHERE downloadStatus = 'P' ORDER BY downloadPriority DESC`.
2. Acquires lock for target package.
3. Resolves upstream URL via `rhnContentSource` join and downloads package to `<path>.tmp`.
4. Validates checksum against database record.
5. Atomically moves file to `/var/spacewalk/packages/...` and sets `downloadStatus = 'R'`.

### C. On-Demand Retrieval Flow (Client Request)
1. Client (Zypper/DNF/Minion) requests package via HTTP GET.
2. Interceptor checks if package is present in local cache:
   - **Hit:** Serves package directly through Apache.
   - **Miss:** Interceptor acquires package-specific lock and global concurrency permit.
3. Fetches package upstream, validates checksum, atomically moves to cache, updates database record to `(R)eady`, releases locks, and streams payload back to all waiting client threads.
