# My custom installation script for Arch Linux (uses zsh)
---
## TPM2
- Since Secure Boot state changes on the next boot, enabling TPM2 decryption of LUKS devices is not possible. As an alternative, after the first boot run:
```
# systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 $ROOT_PARTITION
```

