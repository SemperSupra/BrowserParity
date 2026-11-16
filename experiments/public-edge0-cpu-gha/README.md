# Edge0 CPU source and GHA census cross-check

Non-promoting candidate qualification supporting BrowserParity-private #25/#76/#109 and existing authoritative Agent Dispatch runner census private #223 / public github-runner-capability-census.yml.

This experiment runs two independent bounded jobs on standard public ubuntu-24.04 x64 and ubuntu-24.04-arm ARM64 runners, max parallel 2, each timeout 18 minutes. The actual fresh-job preflight reads logical CPU, RAM, free disk and NVMe-named block nodes without host identifiers or secrets. A block node bearing the name nvme does not prove physical NVMe hardware, and its storage is not proven to back the workspace. The observed capacity may differ from other runs and does not establish a service guarantee.

Then it fetches exact Apache-2.0 upstream Edge0 source commit f6bfa5546bcf89919f86946ec669bcc7f4cd526d with sparse Git checkout, builds the native CPU engine and runs real upstream CTest level L0/L1. No model assets or 35B checkpoint are downloaded. No source, artifact, credential, account, local workbench or authenticated session is exported. We deliberately avoid repetitive generic runner surveying, large model downloads and promotion.

Why pursue: Edge0 upstream states its native 35B engine requires approximately 42 GB disk for source plus converted assets; our older private Agent Dispatch runner census observed roughly 92-98 GB free on standard Ubuntu x64 and 116-120 GB free on ARM64. Those observed values make a later, separately admitted full-model workload possible if measured headroom, bandwidth, CPU and exact SHA preflight hold. This run only decides build compatibility and hardware-capacity prerequisites. Successful L0/L1 is not inference, speed, full-weight loading or cache performance evidence.

The follow-on R2 should measure fixed token tasks with actual model weights, compare predicted vs actual routing, and compare smaller fully-resident GGUF as the speed/capability baseline. Require source/model digest, disk/headroom gate and before/after resource accounting. Reconcile DLE and keep draft/unmerged.
