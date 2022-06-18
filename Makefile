SOLANA_BPF_TOOLS_VERSION=v1.27
SOLANA_BPF_TOOLS_ROOT=$(HOME)/.cache/solana/$(SOLANA_BPF_TOOLS_VERSION)/bpf-tools
SOLANA_COMPILER_RT_DIR=$(SOLANA_BPF_TOOLS_ROOT)/rust/lib/rustlib/bpfel-unknown-unknown/lib
SOLANA_RUNTIME_LIB_DIR=$(SOLANA_BPF_TOOLS_ROOT)/llvm/lib
LLVM_ROOT=$(SOLANA_BPF_TOOLS_ROOT)/llvm
CLANG=$(LLVM_ROOT)/bin/clang
CLANGFLAGS=-target bpf -march=bpfel+solana
LD="$(LLVM_ROOT)/bin/ld.lld"
LDFLAGS=

basic.so: basic.o basic.ld
	$(LD) $(LDFLAGS) -z notext -shared --Bdynamic basic.ld --entry entrypoint -L $(SOLANA_RUNTIME_LIB_DIR) -lc -o $@ basic.o $(SOLANA_COMPILER_RT_DIR)/libcompiler_builtins-*.rlib

basic.o: basic.s
	$(CLANG) $(CLANGFLAGS) -c -x assembler -o $@ $<

.PHONY: clean
clean:
	rm -vf *.o *.so
