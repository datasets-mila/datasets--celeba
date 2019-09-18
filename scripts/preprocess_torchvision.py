import torchvision

for split in ("train", "valid", "test", "all"):
    torchvision.datasets.CelebA(".", split=split, download=True)
