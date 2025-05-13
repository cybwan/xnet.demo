#!make
SHELL = bash

INGRESS_ETH  ?= ens34
INGRESS_ETH_IP4 ?= $(shell ip -j -4 a show dev $(INGRESS_ETH) | jq -r .[0].addr_info[0].local)
INGRESS_ETH_MAC ?= $(shell ip -j a show dev $(INGRESS_ETH) | jq -r .[0].address)
INGRESS_ETH_IFI ?= $(shell ip -j a show dev $(INGRESS_ETH) | jq -r .[0].ifindex)

EGRESS_ETH  ?= ens33
EGRESS_ETH_IP4 ?= $(shell ip -j -4 a show dev $(EGRESS_ETH) | jq -r .[0].addr_info[0].local)
EGRESS_ETH_MAC ?= $(shell ip -j a show dev $(EGRESS_ETH) | jq -r .[0].address)
EGRESS_ETH_IFI ?= $(shell ip -j a show dev $(EGRESS_ETH) | jq -r .[0].ifindex)

GW_ADDR ?= $(shell route -n | grep 'UG' | awk '{print $$2}')
GW_MAC ?= $(shell ping $(GW_ADDR) -c 1 > /dev/null 2>&1; arp -n $(GW_ADDR) | awk '{if(NR>1) print $$3}' )

WORK_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BIN_DIR :=  bin

XNET_KERN = xnet.kern

MODE ?= normal

V_ID ?=
V_IP ?=
V_PORT ?=

EP_ID ?=
EP_ADDR ?= 192.168.127.181
EP_PORT ?= 8081
EP_MAC ?= $(shell ping $(EP_ADDR) -c 1 > /dev/null 2>&1; arp -n $(EP_ADDR) | awk '{if(NR>1) print $$3}' )
EP_WEIGHT ?= 100

ifeq ($(strip $(EP_MAC)),)
	EP_MAC = $(GW_MAC)
endif

.PHONY: install-pipy
install-pipy:
	curl -L https://github.com/flomesh-io/pipy/releases/download/1.5.10/pipy-1.5.10-generic_linux-x86_64.tar.gz -o /tmp/pipy.tar.gz
	cd /tmp;tar zxf pipy.tar.gz;cp usr/local/bin/pipy /usr/local/bin/;rm -rf pipy.tar.gz

.PHONY: run-pipy-services
run-pipy-services:
	@sudo nohup pipy -e 'var $msg;pipy.listen("[::]:8081", $=>$.onStart(i => {$msg=`The service is demo1 ! request.remoteAddress: ${i.remoteAddress} request.remotePort:${i.remotePort}\n`}).serveHTTP(() => new Message($msg)))' > /dev/null 2>&1 &
	@sudo nohup pipy -e "pipy().listen('192.168.127.177:8080').serveHTTP(new Message('hi, it works as 192.168.127.177:8080.\n'))" > /dev/null 2>&1 &
	@sudo nohup pipy -e "pipy().listen('192.168.127.178:8080').serveHTTP(new Message('hi, it works as 192.168.127.178:8080.\n'))" > /dev/null 2>&1 &
	@sudo nohup pipy -e "pipy().listen('192.168.127.179:8080').serveHTTP(new Message('hi, it works as 192.168.127.179:8080.\n'))" > /dev/null 2>&1 &

.PHONY: kern-trace
kern-trace:
	@clear
	@sudo cat /sys/kernel/debug/tracing/trace_pipe|grep bpf_trace_printk

.PHONY: xnet-unload
xnet-unload:
	@${BIN_DIR}/xnat bpf detach --sys=e4lb --dev=$(INGRESS_ETH) --tc-ingress=true --tc-egress=true
	@rm -rf /sys/fs/bpf/fsm

.PHONY: xnet-load
xnet-load: xnet-unload
	@echo 1 > /proc/sys/net/ipv4/ip_forward
	@bpftool prog loadall ${BIN_DIR}/${XNET_KERN} /sys/fs/bpf/fsm pinmaps /sys/fs/bpf/fsm > /dev/null 2>&1
	@${BIN_DIR}/xnat prog init
	@${BIN_DIR}/xnat cfg set --sys=e4lb --ipv4 --tcp-nat-by-ip-port-on=1 --tcp-nat-by-ip-on=1 --tcp-nat-by-port-on=1 --tcp-nat-all-on=1 --tcp-nat-by-ip-port-on=1 --tcp-proto-allow-nat-escape=1
	@${BIN_DIR}/xnat cfg set --sys=e4lb --ipv4 --udp-nat-by-ip-port-on=1 --udp-nat-by-ip-on=1 --udp-nat-by-port-on=1 --udp-nat-all-on=1 --udp-nat-by-ip-port-on=1 --udp-proto-allow-nat-escape=1
	@${BIN_DIR}/xnat bpf attach --sys=e4lb --dev=$(INGRESS_ETH) --tc-ingress=true --tc-egress=true > /dev/null 2>&1

.PHONY: add-tcp-nat-rr-ep
add-tcp-nat-rr-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-tcp --mode-$(MODE) --algo-rr --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-tcp-nat-wrr-ep
add-tcp-nat-wrr-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-tcp --mode-$(MODE) --algo-wrr --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --algo-wrr-weight=$(EP_WEIGHT) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-tcp-nat-lc-ep
add-tcp-nat-lc-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-tcp --mode-$(MODE) --algo-lc --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-tcp-nat-wlc-ep
add-tcp-nat-wlc-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-tcp --mode-$(MODE) --algo-wlc --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --algo-wlc-weight=$(EP_WEIGHT) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-tcp-nat-sah-ep
add-tcp-nat-sah-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-tcp --mode-$(MODE) --algo-sah --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)


.PHONY: add-udp-nat-rr-ep
add-udp-nat-rr-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-udp --mode-$(MODE) --algo-rr --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-udp-nat-wrr-ep
add-udp-nat-wrr-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-udp --mode-$(MODE) --algo-wrr --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --algo-wrr-weight=$(EP_WEIGHT) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-udp-nat-lc-ep
add-udp-nat-lc-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-udp --mode-$(MODE) --algo-lc --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-udp-nat-wlc-ep
add-udp-nat-wlc-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-udp --mode-$(MODE) --algo-wlc --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --algo-wlc-weight=$(EP_WEIGHT) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

.PHONY: add-udp-nat-sah-ep
add-udp-nat-sah-ep:
	@${BIN_DIR}/xnat nat add --nat-id=$(V_ID) --sys=e4lb --proto-udp --mode-$(MODE) --algo-sah --addr=$(V_IP) --port=$(V_PORT) --tc-ingress --ep-id=$(EP_ID) --ep-addr=$(EP_ADDR) --ep-port=$(EP_PORT) --ep-mac=$(EP_MAC) --ep-ofi=$(EGRESS_ETH_IFI)

