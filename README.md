

## 1 FLB(4LB) 功能概述

### 1.1 流量处理

```bash
bin/xnat cfg set -h
set global configurations

Usage:
  xnat config set [flags]

Flags:
#三层协议
      --ipv4
      --ipv6
#四层TCP协议
      --tcp-nat-by-ip-port-on int8            #基于目标地址+目标端口流量转发
      --tcp-nat-by-ip-on int8                 #基于目标地址流量转发
      --tcp-nat-by-port-on int8               #基于目标端口流量转发
      --tcp-nat-all-on int8                   #全流量转发
      --tcp-proto-allow-all int8              #全TCP流量放行
      --tcp-proto-allow-nat-escape int8       #无匹配NAT规则的TCP流量放行
      --tcp-proto-deny-all int8               #全TCP流量禁止
#四层UDP协议
      --udp-nat-by-ip-port-on int8            #基于目标地址+目标端口流量转发
      --udp-nat-by-ip-on int8                 #基于目标地址流量转发
      --udp-nat-by-port-on int8               #基于目标端口流量转发
      --udp-nat-all-on int8                   #全流量转发
      --udp-proto-allow-all int8              #全UDP流量放行
      --udp-proto-allow-nat-escape int8       #无匹配NAT规则的UDP流量放行
      --udp-proto-deny-all int8               #全UDP流量禁止
#四层UDP协议
      --oth-proto-deny-all int8               --oth-proto-deny-all=0/1 (default -1)
#黑白名单功能
      --acl-check-on int8
#全流量放行
      --allow-all int8     
#全流量禁止
      --deny-all int8
```

**优先级:**

**nat-by-ip-port > nat-by-ip > nat-by-port > nat-all**

### 1.2 转发处理

```bash
bin/xnat nat add -h
add nat

Usage:
  xnat nat add [flags]

Aliases:
  add, a

Flags:
      --nat-id uint32            --nat-id=0
      --proto-tcp                --proto-tcp=true/false
      --proto-udp                --proto-udp=true/false
      --addr ip                  --addr=0.0.0.0 (default 0.0.0.0)
      --port uint16              --port=0
      --ep-id uint32             --ep-id=0
      --ep-addr ip               --ep-addr=0.0.0.0 (default 0.0.0.0)
      --ep-port uint16           --ep-port=0
      --ep-mac string            --ep-mac=00:00:00:00:00:00
      --ep-ofi uint32            --ep-ofi=0
      --ep-oflags uint8          --ep-oflags=0/1 (egress/ingress)
      --ep-oaddr ip              --ep-oaddr=0.0.0.0 (default 0.0.0.0)
      --ep-omac string           --ep-omac=00:00:00:00:00:00
      --ep-cluster-id uint32     --ep-cluster-id=0
      --ep-active                --ep-active=true/false (default true)
#转发模式
      --mode-normal              #基本模式
      --mode-onearm              #单臂模式
      --mode-full                #全模式
      --mode-l2dsr               #基于2层DSR模式
#负载均衡算法
      --algo-rr                  #轮询 (Round Robin)
      --algo-wrr                 #加权轮询 (Weighted Round Robin)
      --algo-sah                 #源地址哈希 (Source Address Hash)
      --algo-dah                 #目标地址哈希 (Destination Address Hash)
      --algo-lc                  #最少连接 (Least Connections)
      --algo-wlc                 #加权最少连接 (Weighted Least Connections)
      --algo-sed                 #最短期望延迟 (Shortest Expected Delay)
      --algo-nq                  #永不排队 (Never Queue)
#tc 挂载方向
      --tc-egress
      --tc-ingress
```

#### 1.2.1 转发模式

##### 1.2.1.1 基本模式 (normal)

对入向请求采用简单的DNAT（目标网络地址转换），对于出向响应则执行相反的操作（SNAT，源网络地址转换）。

此模式下，原始源IP地址会一直保留至终端节点，需要终端节点需要具备可达源地址的路由能力。

##### 1.2.1.2 单臂模式 (onearm)

将LAN IP作为转发请求的源IP（类似SNAT），突破传统单臂模式对本地LAN的强依赖。

##### 1.2.1.3 全模式 (full)

将入向请求的源IP替换为一个特殊的实例IP，可配合BGP协议向终端节点宣告，有助于在多活集群模式时实现流量的最优分发和扩散。

##### 1.2.1.4 基于2层DSR模式 (l2dsr)

根据选定的终端节点更新二层MAC地址，返回流量绕过LB来减少LB节点的负载。

#### 1.2.2 负载均衡算法

##### 1.2.2.1 轮询（Round Robin, RR）

按顺序将请求依次分配给后端服务器，实现请求的均匀分配

适用场景：后端服务器性能相近且请求处理时间差异较小的场景

静态算法：适合服务器性能固定、无会话保持需求的场景（如静态资源分发）

内核要求: 4.10+

##### 1.2.2.2 加权轮询（Weighted Round Robin, WRR）

在轮询基础上引入权重，根据服务器处理能力（如CPU、内存）分配不同权值。权重越高，接收的请求比例越大

示例：若服务器A权重为3，B为1，则请求分配比例为3:1

静态算法：适合服务器性能固定、无会话保持需求的场景（如静态资源分发）

内核要求: 5.3+

##### 1.2.2.3 源地址哈希（Source Address Hash, SAH）

根据请求的源IP地址进行哈希计算，将同一客户端的请求始终分配到同一台服务器，实现会话保持（Session Persistence）

适用场景：需要保持会话一致性的业务（如登录状态、购物车）

静态算法：会话保持需求

内核要求: 5.3+

##### 1.2.2.4 目标地址哈希（Destination Address Hash, DAH）

根据请求的目标IP地址进行哈希计算，将相同目标地址的请求分配到同一台服务器，常用于缓存集群以提高缓存命中率

适用场景：正向代理缓存（如CDN节点）

静态算法：会话保持需求

内核要求: 5.3+

##### 1.2.2.5 最少连接（Least Connections, LC）

将新请求分配给当前活跃连接数最少的服务器

公式：选择 active_connections 最小的服务器

局限性：未考虑服务器权重，可能导致性能强的服务器未充分利用

动态算法：适合服务器性能差异大或请求处理时间波动大的场景（如API网关、数据库集群）

内核要求: 5.3+

##### 1.2.2.6 加权最少连接（Weighted Least Connections, WLC）

在LC基础上引入权重，优先选择 active_connections / weight 比值最小的服务器。

公式：Score = (active_connections × 256 + inactive_connections) / weight。

优势：兼顾连接数和性能差异，推荐算法

动态算法：适合服务器性能差异大或请求处理时间波动大的场景（如API网关、数据库集群）

内核要求: 5.3+

##### 1.2.2.7 最短期望延迟（Shortest Expected Delay, SED）

优化WLC算法，计算公式为 (active_connections + 1) × 256 / weight，优先分配预期延迟最低的服务器

适用场景：需要减少请求响应时间的敏感业务

动态算法：适合服务器性能差异大或请求处理时间波动大的场景（如API网关、数据库集群）

内核要求: 5.3+

##### 1.2.2.8 永不排队（Never Queue, NQ）

若某服务器当前无活跃连接（active_connections = 0），则直接分配请求，否则退化为SED算法

优势：避免新请求因服务器队列过长而延迟

动态算法：适合服务器性能差异大或请求处理时间波动大的场景（如API网关、数据库集群）

内核要求: 5.3+

## 2 FLB(4LB) 功能测试

### 2.1 测试环境

三台虚拟机

**单网卡VM Client (ens34) <--192.168.226.0/24--> (ens34) 双网卡VM FLB (ens33) <--192.168.127.0/24--> (ens33) 单网卡多 IP VM Server**

#### 2.1.1 网络配置

##### 2.1.1.1 Client节点 网络配置

```bash
root@client1:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: ens34: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:e5:e6:fe brd ff:ff:ff:ff:ff:ff
    altname enp2s2
    inet 192.168.226.161/24 brd 192.168.226.255 scope global ens34
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fee5:e6fe/64 scope link 
       valid_lft forever preferred_lft forever
```

##### 2.1.1.2 FLB节点 网络配置

```bash
root@flb:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1436 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:f3:6d:dd brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 192.168.127.175/24 brd 192.168.127.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fef3:6ddd/64 scope link 
       valid_lft forever preferred_lft forever
3: ens34: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:f3:6d:e7 brd ff:ff:ff:ff:ff:ff
    altname enp2s2
    inet 192.168.226.175/24 brd 192.168.226.255 scope global ens34
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fef3:6de7/64 scope link 
       valid_lft forever preferred_lft forever
```

##### 2.1.1.3 Server节点 网络配置

**ens33上配置多个 IP,模拟多台虚拟机**

```bash
root@servers:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1436 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:e7:c9:2f brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 192.168.127.181/24 brd 192.168.127.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet 192.168.127.182/24 brd 192.168.127.255 scope global secondary ens33
       valid_lft forever preferred_lft forever
    inet 192.168.127.183/24 brd 192.168.127.255 scope global secondary ens33
       valid_lft forever preferred_lft forever
    inet 192.168.127.184/24 brd 192.168.127.255 scope global secondary ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fee7:c92f/64 scope link 
       valid_lft forever preferred_lft forever
```

#### 2.1.2 路由配置

##### 2.1.2.1 Client节点

**配置虚拟 IP 网段(17.17.17.0/24)的路由到 FLB 节点**

```bash
ip r add 17.17.17.0/24 via 192.168.226.175
```

##### 2.1.2.2 Server节点

**后续测试源地址透传, Server节点需要维护经 FLB 节点到 Client 节点的路由:**

```bash
ip r add 192.168.226.0/24 via 192.168.127.175
```

### 2.2 测试目标

#### 2.2.1 Server节点准备

**在server节点的多个 IP 上启动 HTTP DEMO 服务: 每次请求返回服务实例名,远端地址及远端端口**

```bash
cd /tmp

curl -L https://github.com/flomesh-io/pipy/releases/download/1.5.10/pipy-1.5.10-generic_linux-x86_64.tar.gz -o /tmp/pipy.tar.gz
tar zxf pipy.tar.gz
cp usr/local/bin/pipy /usr/local/bin/pipy
rm -rf pipy.tar.gz

curl -L https://github.com/cybwan/xnet.demo/raw/refs/heads/main/tools/dnsd -o /usr/local/bin/dnsd
chmod u+x /usr/local/bin/dnsd

sudo nohup pipy -e 'var $msg;pipy.listen("192.168.127.181:8081", $=>$.onStart(i => {$msg=`The service is demo1 ! request.remoteAddress: ${i.remoteAddress} request.remotePort:${i.remotePort}\n`}).serveHTTP(() => new Message($msg)))' > /dev/null 2>&1 &

sudo nohup pipy -e 'var $msg;pipy.listen("192.168.127.182:8082", $=>$.onStart(i => {$msg=`The service is demo2 ! request.remoteAddress: ${i.remoteAddress} request.remotePort:${i.remotePort}\n`}).serveHTTP(() => new Message($msg)))' > /dev/null 2>&1 &

sudo nohup pipy -e 'var $msg;pipy.listen("192.168.127.183:8083", $=>$.onStart(i => {$msg=`The service is demo3 ! request.remoteAddress: ${i.remoteAddress} request.remotePort:${i.remotePort}\n`}).serveHTTP(() => new Message($msg)))' > /dev/null 2>&1 &

sudo nohup pipy -e 'var $msg;pipy.listen("192.168.127.184:8084", $=>$.onStart(i => {$msg=`The service is demo4 ! request.remoteAddress: ${i.remoteAddress} request.remotePort:${i.remotePort}\n`}).serveHTTP(() => new Message($msg)))' > /dev/null 2>&1 &

#只接受域名后缀为cluster.local的 DNS 请求,且解析都返回 1.1.1.1
sudo nohup dnsd server --laddr=0.0.0.0:1153 --trust-domain=cluster.local --wildcard-a-addr=1.1.1.1 > /dev/null 2>&1 &
```

#### 2.2.2 FLB节点准备

**下载 flb xnet 组件:**

```bash
cd /tmp
git clone https://github.com/cybwan/xnet.demo.git
cd xnet.demo
```

**加载 flb xnet 组件:**

```bash
make xnet-load
```

#### 2.2.3 验证基于比例路由

**基于比例路由，即V_IP=0.0.0.0 V_PORT=0，同时使用 wrr 或 wlc 算法，基于权重设置路由比例**

**FLB 节点上设置 NAT 规则:**

```bash
V_ID=1 V_IP=0.0.0.0 V_PORT=0 EP_ID=1 EP_WEIGHT=25 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-wrr-ep
V_ID=1 V_IP=0.0.0.0 V_PORT=0 EP_ID=2 EP_WEIGHT=75 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-wrr-ep
```

**Client节点上发起 8 次请求:**

```bash
echo $(curl -s 17.17.17.201:10201)
echo $(curl -s 17.17.17.202:10202)
echo $(curl -s 17.17.17.203:10203)
echo $(curl -s 17.17.17.204:10204)
echo $(curl -s 17.17.17.205:10205)
echo $(curl -s 17.17.17.206:10206)
echo $(curl -s 17.17.17.207:10207)
echo $(curl -s 17.17.17.208:10208)
```

**Client节点上返回信息:**

```logs
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:60976
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:57476
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:41840
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:49972
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:38568
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:57012
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:35678
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:56916
```

**分析返回结果: 2 个连接由 demo1 处理，6 个连接由 demo2 处理，符合设置的比例规则.**

#### 2.2.4 验证基于VPORT路由

**基于VPORT路由，即V_IP=0.0.0.0，算法不限，本次验证使用 rr 算法**

**FLB 节点上设置 NAT 规则:**

```bash
V_ID=2 V_IP=0.0.0.0 V_PORT=8080 EP_ID=1 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-rr-ep
V_ID=2 V_IP=0.0.0.0 V_PORT=8080 EP_ID=2 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-rr-ep
V_ID=2 V_IP=0.0.0.0 V_PORT=8080 EP_ID=3 EP_ADDR=192.168.127.183 EP_PORT=8083 make add-tcp-nat-rr-ep
V_ID=2 V_IP=0.0.0.0 V_PORT=8080 EP_ID=4 EP_ADDR=192.168.127.184 EP_PORT=8084 make add-tcp-nat-rr-ep
```

**Client节点上发起 8 次请求:**

```bash
echo $(curl -s 17.17.17.201:8080)
echo $(curl -s 17.17.17.202:8080)
echo $(curl -s 17.17.17.203:8080)
echo $(curl -s 17.17.17.204:8080)
echo $(curl -s 17.17.17.205:8080)
echo $(curl -s 17.17.17.206:8080)
echo $(curl -s 17.17.17.207:8080)
echo $(curl -s 17.17.17.208:8080)
```

**Client节点上返回信息:**

```logs
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:45902
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:59536
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:38226
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:44176
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:40832
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:41848
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:52848
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:41134
```

**分析返回结果:  访问不存在的 VIP，能正确处理，符合设置的NAT规则.**

#### 2.2.5 验证基于VIP路由

**基于VIP路由，即V_PORT=0，算法不限，本次验证使用 rr 算法**

**FLB 节点上设置 NAT 规则:**

```bash
V_ID=3 V_IP=17.17.17.1 V_PORT=0 EP_ID=1 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-rr-ep
V_ID=3 V_IP=17.17.17.1 V_PORT=0 EP_ID=2 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-rr-ep
V_ID=3 V_IP=17.17.17.1 V_PORT=0 EP_ID=3 EP_ADDR=192.168.127.183 EP_PORT=8083 make add-tcp-nat-rr-ep
V_ID=3 V_IP=17.17.17.1 V_PORT=0 EP_ID=4 EP_ADDR=192.168.127.184 EP_PORT=8084 make add-tcp-nat-rr-ep
```

**Client节点上发起 8 次请求:**

```bash
echo $(curl -s 17.17.17.1:12201)
echo $(curl -s 17.17.17.1:12202)
echo $(curl -s 17.17.17.1:12203)
echo $(curl -s 17.17.17.1:12204)
echo $(curl -s 17.17.17.1:12205)
echo $(curl -s 17.17.17.1:12206)
echo $(curl -s 17.17.17.1:12207)
echo $(curl -s 17.17.17.1:12208)
```

**Client节点上返回信息:**

```logs
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:44456
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:53762
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:51156
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:34370
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:36116
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:47734
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:39166
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:49812
```

**分析返回结果:  访问不存在的 VPORT，能正确处理，符合设置的NAT规则.**

#### 2.2.6 验证基于VIP+VPORT路由

##### **2.2.6.1 验证轮询负载算法**

**FLB 节点上设置 RR NAT 规则:**

```bash
V_ID=4 V_IP=17.17.17.2 V_PORT=8080 EP_ID=1 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-rr-ep
V_ID=4 V_IP=17.17.17.2 V_PORT=8080 EP_ID=2 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-rr-ep
V_ID=4 V_IP=17.17.17.2 V_PORT=8080 EP_ID=3 EP_ADDR=192.168.127.183 EP_PORT=8083 make add-tcp-nat-rr-ep
V_ID=4 V_IP=17.17.17.2 V_PORT=8080 EP_ID=4 EP_ADDR=192.168.127.184 EP_PORT=8084 make add-tcp-nat-rr-ep
```

**Client节点上发起 8 次请求:**

```bash
echo $(curl -s 17.17.17.2:8080)
echo $(curl -s 17.17.17.2:8080)
echo $(curl -s 17.17.17.2:8080)
echo $(curl -s 17.17.17.2:8080)
echo $(curl -s 17.17.17.2:8080)
echo $(curl -s 17.17.17.2:8080)
echo $(curl -s 17.17.17.2:8080)
echo $(curl -s 17.17.17.2:8080)
```

**Client节点上返回信息:**

```logs
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:57934
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:57940
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:57942
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:57948
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:57956
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:57958
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:57968
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:57982
```

**分析返回结果:  demo1~demo4 轮流处理请求，符合设置的NAT规则.**

##### 2.2.6.2 验证源地址透传

**基于 2.2.6.1 设置的NAT规则，Client节点上发起 8 次请求:**

```bash
echo $(curl --local-port 18001 -s 17.17.17.2:8080)
echo $(curl --local-port 18002 -s 17.17.17.2:8080)
echo $(curl --local-port 18003 -s 17.17.17.2:8080)
echo $(curl --local-port 18004 -s 17.17.17.2:8080)
echo $(curl --local-port 18005 -s 17.17.17.2:8080)
echo $(curl --local-port 18006 -s 17.17.17.2:8080)
echo $(curl --local-port 18007 -s 17.17.17.2:8080)
echo $(curl --local-port 18008 -s 17.17.17.2:8080)
```

**Client节点上返回信息:**

```logs
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:18001
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:18002
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:18003
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:18004
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:18005
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:18006
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:18007
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:18008
```

**分析返回结果:  请求返回的remoteAddress及remotePort同请求时使用的地址和端口一致，符合源地址透传.**

##### 2.2.6.3 验证加权轮询负载算法

**FLB 节点上设置 WRR NAT 规则:**

```bash
V_ID=5 V_IP=17.17.17.3 V_PORT=8080 EP_ID=1 EP_WEIGHT=25 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-wrr-ep
V_ID=5 V_IP=17.17.17.3 V_PORT=8080 EP_ID=2 EP_WEIGHT=75 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-wrr-ep
```

**Client节点上发起 8 次请求:**

```bash
echo $(curl -s 17.17.17.3:8080)
echo $(curl -s 17.17.17.3:8080)
echo $(curl -s 17.17.17.3:8080)
echo $(curl -s 17.17.17.3:8080)
echo $(curl -s 17.17.17.3:8080)
echo $(curl -s 17.17.17.3:8080)
echo $(curl -s 17.17.17.3:8080)
echo $(curl -s 17.17.17.3:8080)
```

**Client节点上返回信息:**

```logs
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:46660
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:46664
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:46678
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:46688
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:46700
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:46706
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:46716
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:46728
```

**分析返回结果: 2 个连接由 demo1 处理，6 个连接由 demo2 处理，符合设置的权重规则.**

##### 2.2.6.4 验证最小连接数负载算法

**FLB 节点上设置 LC NAT 规则:**

```bash
V_ID=5 V_IP=17.17.17.4 V_PORT=8080 EP_ID=1 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-lc-ep
V_ID=5 V_IP=17.17.17.4 V_PORT=8080 EP_ID=2 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-lc-ep
V_ID=5 V_IP=17.17.17.4 V_PORT=8080 EP_ID=3 EP_ADDR=192.168.127.183 EP_PORT=8083 make add-tcp-nat-lc-ep
V_ID=5 V_IP=17.17.17.4 V_PORT=8080 EP_ID=4 EP_ADDR=192.168.127.184 EP_PORT=8084 make add-tcp-nat-lc-ep
```

**Client节点上发起 8 次请求:**

```bash
echo $(curl -s 17.17.17.4:8080)
echo $(curl -s 17.17.17.4:8080)
echo $(curl -s 17.17.17.4:8080)
echo $(curl -s 17.17.17.4:8080)
echo $(curl -s 17.17.17.4:8080)
echo $(curl -s 17.17.17.4:8080)
echo $(curl -s 17.17.17.4:8080)
echo $(curl -s 17.17.17.4:8080)
```

**Client节点上返回信息:**

```logs
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:45646
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:45656
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:45664
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:45668
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:45672
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:45682
The service is demo3 ! request.remoteAddress: 192.168.226.161 request.remotePort:45686
The service is demo4 ! request.remoteAddress: 192.168.226.161 request.remotePort:45690
```

**分析返回结果:  demo1~demo4 最小连接数节点轮流处理请求，符合设置的NAT规则.**

##### 2.2.6.5 验证加权最小连接数负载算法

**FLB 节点上设置 WLC NAT 规则:**

```bash
V_ID=6 V_IP=17.17.17.5 V_PORT=8080 EP_ID=1 EP_WEIGHT=25 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-wlc-ep
V_ID=6 V_IP=17.17.17.5 V_PORT=8080 EP_ID=2 EP_WEIGHT=75 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-wlc-ep
```

**Client节点上发起 8 次请求:**

```bash
echo $(curl -s 17.17.17.5:8080)
echo $(curl -s 17.17.17.5:8080)
echo $(curl -s 17.17.17.5:8080)
echo $(curl -s 17.17.17.5:8080)
echo $(curl -s 17.17.17.5:8080)
echo $(curl -s 17.17.17.5:8080)
echo $(curl -s 17.17.17.5:8080)
echo $(curl -s 17.17.17.5:8080)
```

**Client节点上返回信息:**

```logs
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:38238
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:38248
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:38250
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:38266
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:38272
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:38274
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:38280
The service is demo2 ! request.remoteAddress: 192.168.226.161 request.remotePort:38288
```

**分析返回结果: 2 个连接由 demo1 处理，6 个连接由 demo2 处理，符合设置的最小连接数权重规则.**

##### 2.2.6.6 验证源地址哈希负载算法

**FLB 节点上设置 SAH NAT 规则:**

```bash
V_ID=7 V_IP=17.17.17.6 V_PORT=8080 EP_ID=1 EP_ADDR=192.168.127.181 EP_PORT=8081 make add-tcp-nat-sah-ep
V_ID=7 V_IP=17.17.17.6 V_PORT=8080 EP_ID=2 EP_ADDR=192.168.127.182 EP_PORT=8082 make add-tcp-nat-sah-ep
V_ID=7 V_IP=17.17.17.6 V_PORT=8080 EP_ID=3 EP_ADDR=192.168.127.183 EP_PORT=8083 make add-tcp-nat-sah-ep
V_ID=7 V_IP=17.17.17.6 V_PORT=8080 EP_ID=4 EP_ADDR=192.168.127.184 EP_PORT=8084 make add-tcp-nat-sah-ep
```

**Client节点网卡设置多 IP:**

```bash
ip a add 192.168.226.162/24 dev ens34
```

**Client节点上从192.168.226.161地址发起 8 次请求:**

```bash
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.161 -s 17.17.17.6:8080)
```

**Client节点上返回信息:**

```logs
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43774
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43776
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43782
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43796
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43800
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43814
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43820
The service is demo1 ! request.remoteAddress: 192.168.226.161 request.remotePort:43824
```

**分析返回结果:  因为源地址相同，请求都由demo1处理.**

**Client节点上从192.168.226.162地址发起 8 次请求:**

```bash
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
echo $(curl --interface 192.168.226.162 -s 17.17.17.6:8080)
```

**Client节点上返回信息:**

```logs
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45140
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45152
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45164
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45168
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45172
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45182
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45190
The service is demo4 ! request.remoteAddress: 192.168.226.162 request.remotePort:45206
```

**分析返回结果:  因为源地址相同，请求都由demo4处理.**

**分析两轮返回结果: 符合设置的NAT规则.**

#### 2.2.7 验证UDP协议

**劫持 DNS 请求**

**FLB 节点上设置 NAT 规则:**

```bash
V_ID=8 V_IP=0.0.0.0 V_PORT=53 EP_ID=1 EP_ADDR=192.168.127.181 EP_PORT=1153 make add-udp-nat-rr-ep
```

**Client节点上发起 8 次请求:**

```bash
nslookup demo171.cluster.local 17.17.17.171
nslookup demo172.cluster.local 17.17.17.172
nslookup demo173.cluster.local 17.17.17.173
nslookup demo174.cluster.local 17.17.17.174
nslookup demo175.cluster.local 17.17.17.175
nslookup demo176.cluster.local 17.17.17.176
nslookup demo177.cluster.local 17.17.17.177
nslookup demo178.cluster.local 17.17.17.178
```

**Client节点上返回信息类似:**

```logs
Server:         17.17.17.178
Address:        17.17.17.178#53

Non-authoritative answer:
Name:   demo178.cluster.local
Address: 1.1.1.1
Name:   demo178.cluster.local
Address: ::1.1.1.1
```

**分析返回结果: DNS 的解析请求都被拦截到192.168.127.181:1153.**
