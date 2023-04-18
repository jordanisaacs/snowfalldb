# Confidential Computing Notes

These notes cover what confidential computing, implementations, and uses

## What is confidential Computing

[link](https://spectrum.ieee.org/what-is-confidential-computing)

Confidential computing is about protecting data while in use. So malware can't just dump your memory while you are computing on it. This is important for cloud computing because when you don't control the datacenter and hardware, you can't trust that the host OS isn't compromised.

# Intel SGX

# AMD SEV

* [AMD Developer Page](https://developer.amd.com/sev/)

## AMD SEV-SNP Whitepaper

[link](https://www.amd.com/system/files/TechDocs/SEV-SNP-strengthening-vm-isolation-with-integrity-protection-and-more.pdf)

SEV (Secure Encrypted Virtualization) enabled main memory encryption. Individual VMs could be assigned unique AES encryption keys to encrypt in-use data. When the hypervisor tries to read memory inside a guest, only sees encrypted bytes.

SEV-ES (SEV - Encrypted State) enabled additional protection for CPU register state. Each VM's register state was encrypted during the hypervisor transition so hypervisor can't see data being used by the VM.

SEV-SNP (SEV - Secure Nested Paging) adds strong memory integrity protection

SEV encryption key is generated from hardware RNG and stored in dedicated hardware register. Software can't directly read it. Identical plaintext at different memory lcoations are encrypted differently.

An attacker can change values in memory without knowing the encryption key - an *integrity attack*. Can corrupt memory so VM gets random values. VM is generally unaware when memory integrity is compromised and situation is hard to predict.

> The basic principle of SEV-SNP integrity is that if a VM is able to read a private (encrypted) page of memory, it must always read the value it last wrote.

## The Linux SVSM project

[link](https://lwn.net/Articles/921266/)

# A Comparison Study of Intel SGX and AMD Memory Encryption Technology

[link](https://caslab.csl.yale.edu/workshops/hasp2018/HASP18_a9-mofrad_slides.pdf)

