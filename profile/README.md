# andrelair-platform

**IT infrastructure organization powering [ktayl-solution](https://ktayl.devandre.sbs)** — a specialty insurance consulting firm operating across 7 lines of business: Marine, Aviation, Property & Engineering, Liability, Financial Lines, Energy, and Cyber.

This org contains every repo needed to build, deploy, and operate the company's private cloud platform — from bare-metal provisioning to AI services.

---

## About ktayl-solution

ktayl-solution provides independent risk advisory and insurance placement for complex global risks. Its consultants place programmes in Lloyd's, Bermuda, European, and international specialty markets across:

| Line | Focus |
|---|---|
| 🚢 Marine | Cargo, Hull & Marine Liability |
| ✈️ Aviation | Aircraft Hull, Liability & Passenger Risk |
| 🏗️ Property & Engineering | Industrial All Risk, Construction & Machinery |
| ⚖️ Liability | General, Products & Employer's Liability |
| 📊 Financial Lines | D&O, E&O, Crime & Management Liability |
| ⚡ Energy | Offshore, Onshore & Renewable Energy |
| 🔐 Cyber | Cyber Risk, Data Breach & Business Interruption |

→ [ktayl.devandre.sbs](https://ktayl.devandre.sbs)

---

## What this org provides

andrelair-platform is the internal IT department — built from scratch on bare-metal hardware to the same standards a tier-1 financial institution would apply.

**Platform layer**
- Bare-metal provisioning: MAAS + PXE boot, Ubuntu 22.04, cloud-init on 5 laptops (4 ThinkPad X390s + 1 MacBook Pro 2012)
- k3s cluster (1 control-plane + 4 workers) behind Tailscale mesh
- GitOps delivery: ArgoCD app-of-apps, Kustomize base+overlays, 3-branch CI promotion (dev → staging → prod)
- Zero-trust network: OPA Gatekeeper in deny mode across 23 namespaces, NetworkPolicy on every service
- Secrets management: HashiCorp Vault with Kubernetes auth + AWS KMS auto-unseal
- SSO: Authentik OIDC protecting all internal tools (ArgoCD, Grafana, Harbor, Backstage, Open WebUI, Vaultwarden)
- Observability: Prometheus · Grafana · Loki · Tempo · Alertmanager
- Storage & DR: Longhorn distributed block storage · Velero backups → MinIO (daily, 7-day TTL)
- Registry: Harbor with cosign image signing + SBOM on every custom image

**AI services — built for insurance workflows**
- Self-hosted LLMs: Ollama + Open WebUI (advisor AI chat)
- Enterprise RAG pipeline: French insurance document ingestion → Docling OCR → structure-aware chunking (articles, clauses, annexes) → bge-m3 embeddings → pgvector HNSW + BM25 hybrid search
- phi3-financial: domain-restricted AI assistant for Financial Lines (D&O, E&O, Crime) with PromptOps architecture — runtime prompt injection via LiteLLM + Langfuse, 25-case eval suite enforcing 100% pass rate as deployment gate
- LLM tracing & eval: Langfuse + LiteLLM router across local and cloud providers

---

## Repositories

| Repo | Purpose |
|---|---|
| [minicloud-gitops](https://github.com/andrelair-platform/minicloud-gitops) | GitOps source of truth — all Helm values and ArgoCD Applications |
| [minicloud-ansible](https://github.com/andrelair-platform/minicloud-ansible) | Bare-metal bootstrap and Day-2 rolling upgrades |
| [minicloud-opentofu](https://github.com/andrelair-platform/minicloud-opentofu) | MAAS infrastructure-as-code via OpenTofu |
| [minicloud-platform-docs](https://github.com/andrelair-platform/minicloud-platform-docs) | Platform runbooks and engineering blog |
| [minicloud-backstage](https://github.com/andrelair-platform/minicloud-backstage) | Custom Backstage image (internal developer portal) |
| [minicloud-open-webui](https://github.com/andrelair-platform/minicloud-open-webui) | Custom Open WebUI image (CA cert + French BM25 baked in) |
| [minicloud-rag-ingest](https://github.com/andrelair-platform/minicloud-rag-ingest) | RAG ingestion service: convert → chunk → embed → pgvector |
| [minicloud-markitdown-proxy](https://github.com/andrelair-platform/minicloud-markitdown-proxy) | Document conversion proxy: PDF/images → Docling, Office → MarkItDown |
| [minicloud-postgresql-noavx512](https://github.com/andrelair-platform/minicloud-postgresql-noavx512) | Custom PostgreSQL image with pgvector rebuilt without AVX-512 |
| [minicloud-rag-eval](https://github.com/andrelair-platform/minicloud-rag-eval) | RAG evaluation harness |
| [platform-demo](https://github.com/andrelair-platform/platform-demo) | Go CI/CD demo service — full pipeline reference |
| [ktayl-solution-web](https://github.com/andrelair-platform/ktayl-solution-web) | ktayl-solution public website (Astro + Tailwind) |

---

## Docs & runbooks

Full operational runbooks, phase history, regression checks, and architecture notes:  
→ [andrelair-platform.github.io/minicloud-platform-docs](https://andrelair-platform.github.io/minicloud-platform-docs/)

Engineering blog:  
→ [andrelair-platform.github.io/minicloud-platform-docs/blog](https://andrelair-platform.github.io/minicloud-platform-docs/blog)

---

*Built and operated by [@AndreLiar](https://github.com/AndreLiar) — Platform Engineer · AI Engineer · Software Engineer*  
*RNCP 39583 · Niveau 7 · Expert en développement logiciel*
