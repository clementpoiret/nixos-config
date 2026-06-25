import torch

print("torch:", torch.__version__)
print("HIP:", torch.version.hip)
print("available:", torch.cuda.is_available())

if not torch.cuda.is_available():
    raise SystemExit("PyTorch did not detect a ROCm GPU")

props = torch.cuda.get_device_properties(0)
print("device:", props.name)
print("gcnArchName:", getattr(props, "gcnArchName", None))
print("total_memory_gib:", round(props.total_memory / 1024**3, 2))

x = torch.randn((1024, 1024), device="cuda")
print("mean:", float((x @ x).mean()))
