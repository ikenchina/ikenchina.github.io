---
category: "read"
title:  "grpc"
categories: 
- 2018
tags:
- rpc
- grpc
date: 2018-06-02
---


> grpc 特性、原理、实践、生态<!-- more -->  



# gRPC



# 概述


gRPC是一个由google设计开发基于HTTP/2协议和Protobuf序列化协议的的高性能、多语言、通用的开源 RPC 框架。  


跨语言、跨平台   
插件化 ： 负载均衡，tracing，健康检查，认证等等  
编码压缩 ： 节省带宽 
多路复用 ： 降低的 TCP 链接次数



**使用场景**

- 低延迟、高扩展的分布式系统
- 与云服务通信
- 设计一个需要准确，高效且与语言无关的新协议
- 分层设计，以实现扩展，例如：身份验证，负载平衡，日志记录和监控等




# 特性

**基于HTTP/2**

HTTP/2 提供了 链接多路复用、双向流、服务器推送、请求优先级、首部压缩等机制。  
gRPC 协议使用了HTTP2 现有的语义，请求和响应的数据使用HTTP Body 发送，其他的控制信息则用Header 表示。


**IDL使用ProtoBuffer**

gRPC使用ProtoBuf来定义服务，ProtoBuf是由Google开发的一种数据序列化协议（类似于XML、JSON）。   
ProtoBuf能够将数据进行序列化，并广泛应用在数据存储、通信协议等方面。  
压缩和传输效率高，向后兼容，语法简单，表达力强。


**多语言支持**

gRPC支持多种语言，并能够基于语言自动生成客户端和服务端。  

目前支持： C#, C++, Dart, Go, Java, Node, Objective-C, PHP, Python, Ruby 等。 

[详见官网](https://grpc.io/docs/quickstart/)


# HTTP/2

## HTTP/2

HTTP/1.x 是超文本传输协议第1版，可读性好，但效率不高。  
而HTTP/2 是超文本传输协议第2版，是一个二进制协议。

HTTP/1 和 HTTP/2 的基本语义并没有改变，如方法语义（GET/PUST/PUT/DELETE），状态码（200/404/500等），Range Request，Cacheing，Authentication、URL路径。


**HTTP/2通用术语：**
- Stream： 流，一个双向流，一条连接可以有多个 streams。
- Message： 逻辑上面的 request，response。
- Frame：帧，HTTP/2 数据传输的最小单位。每个 Frame 都属于一个特定的 stream。一个 message 可能由多个 frame 组成。



**HTTP/2 流、帧**   

HTTP/2连接上传输的每个帧(frame)都关联到一个流，一个连接上可以同时有多个流，
同一个流的帧按序传输，不同流的帧交错混合传输，
客户端、服务端双方都可以建立流，流也可以被任意一方关闭。  
客户端发起的流使用奇数流ID，服务端发起的使用偶数。


[Frame结构 : ](https://httpwg.org/specs/rfc7540.html#rfc.section.4.1)
```
+-----------------------------------------------+
|                 Length (24)                   |
+---------------+---------------+---------------+
|   Type (8)    |   Flags (8)   |
+-+-------------+---------------+-------------------------------+
|R|                 Stream Identifier (31)                      |
+=+=============================================================+
|                   Frame Payload (0...)                      ...
+---------------------------------------------------------------+
```

- Length ： 也就是 Frame 的长度
- Type ：Frame 的类型，有 DATA，HEADERS，SETTINGS 等
- Flags ：帧标志位，8个比特表示可以容纳8个不同的标志：stream是否结束(END_STREAM)，header是否结束(END_HEADERS)，priority等等
- R：保留位
- Stream Identifier：标识frame所属的 stream，如果为 0，则表示这个 frame 属于整条连接(如SETTINGS帧)
- Frame Payload：帧内容




**帧类型**  
- HEADERS 类似于HTTP/1的 Headers
- DATA 类似于HTTP/1的 Body
- CONTINUATION 头部太大，分多个帧传输（一个HEADERS+若干CONTINUATION）
- SETTINGS 连接设置
- WINDOW_UPDATE 流量控制
- PUSH_PROMISE 服务端推送
- PRIORITY 流优先级更改
- PING 心跳或计算RTT
- RST_STREAM 马上中止一个流
- GOAWAY 关闭连接并且发送错误信息



## HTTP/2 特性

**新的二进制格式（Binary Format）**

HTTP/1 的解析是基于文本。基于文本协议的格式解析存在天然缺陷，文本的表现形式有多样性，要做到健壮性考虑的场景必然很多，二进制则不同。  
基于这种考虑HTTP/2的协议解析决定采用二进制格式，实现方便且健壮。



**多路复用（MultiPlexing）**

HTTP/1 的request是阻塞的，如果想并发发送多个request，必须使用多个 TCP connection。这样会消耗更多资源，且浏览器为了控制资源，会对单个域名有TCP connection请求限制。

HTTP/2 一个TCP connection可以有多个streams(最大数量由参数SETTINGS_MAX_CONCURRENT_STREAMS控制)， 多个streams 并行发送不同的请求的frames。  


可以在SETTINGS帧中设置`SETTINGS_MAX_CONCURRENT_STREAMS`。  
而此值是针对一端而言的，客户端可以告知服务器最大的streams并发数，服务端也可以告知客户端。  

> 如果一条链接上 ID 分配完了， server 则会给 client 发送一个 GOAWAY frame 强制让 client 新建一条连接。



**header压缩**

HTTP/1 是使用文本协议，而且header每次都要重复发送，浪费了带宽也导致资源加载过慢。

HTTP/2 采取了压缩和缓存来避免重复发送和带宽问题：
- 对消息头采用HPACK 进行压缩传输来节省消息头占用的网络的流量。
- 对这些headers采取了压缩策略来减少重复headers的请求数
  - HTTP/2在客户端和服务器端使用 headlist 来存储之前发送过的 header，对于相同的header，不再通过每次请求和响应发送；


[HPACK: Header Compression for HTTP/2](http://http2.github.io/http2-spec/compression.html)


**服务端推送**

server push功能 : 在无需客户端请求资源的情况下，服务端会直接推送客户端可能需要的资源到客户端。  


当服务器想用Server Push推送资源时，会先向客户端发送PUSH_PROMISE帧。
推送的响应必须与客户端的某个请求相关联，因此服务器会在客户端请求的流上发送PUSH_PROMISE帧。




**优先级排序**

设置优先级的目的是为了告诉对端在并发的多个流之间如何分配资源的行为，同时当发送容量有限时，可以使用优先级来选择用于发送帧的流。  

客户端可以通过 HEADERS 帧的 PRIORITY 信息指定一个新建立流的优先级，也可以发送 PRIORITY 帧调整流优先级。

[参考官网](http://http2.github.io/http2-spec/#StreamPriority)


**Flow Control**

HTTP/2 支持流控，receiver 端可以对某些stream进行流控也可以针对整个connection流控。  
而TCP层只能针对整个connection进行流控。  


特性 ：
- Flow control 是由方向的 : Receiver 可以选择给 stream 或者整个连接设置接收端的 window size。
- Flow control 是基于信任的 : Receiver 只是会给 sender 建议 连接和 stream 的 flow control window size。
- Flow control 无法禁止 
- Flow control 是基于WINDOW_UPDATE帧的
- Flow control 是 hop-by-hop的，而不是 end-to-end 的。例如，用nginx做proxy，则flow control作用于nginx到server和client到nginx这两个connection。


> Connection 和 stream 的初始 flow-control window 大小都是 65535。  
Connection 的初始窗口大小不能改变，但 stream 的可以(所有stream)，通过发送 SETTINGS 帧，携带 `SETTINGS_INITIAL_WINDOW_SIZE`，这个值即为新的 stream flow-control window 初始大小。



> 增加flow control window size能加快数据传输，但同时会消耗更多资源。



**主动重置链接**

HTTP/1 的body的length的被送给客户端后，服务端就无法中断请求了，只能断开整个TCP connection，但这样导致的代价就是需要重新通过三次握手建立一个新的TCP连接。

HTTP/2 引入了一个 RST_STREAM frame 来让客户端在已有的连接中发送重置请求，从而中断或者放弃响应。当浏览器进行页面跳转或者用户取消下载时，它可以防止建立新连接，避免浪费所有带宽。


## HTTP/2 站点demo

HTTP/1 和 HTTP/2 加载速度比较：   
https://http2.akamai.com/demo

访问http2站点 ：  
https://http2.golang.org/



# ProtoBuf 

## ProtoBuf 

**Google Protocol Buffer**  

是一种轻便高效的结构化数据存储格式，可以用于结构化数据序列化。适合做数据存储或 RPC 数据交换格式。可用于通讯协议、数据存储等领域的语言无关、平台无关、可扩展的序列化结构数据格式。


- 描述简单，对开发人员友好
- 跨平台、跨语言，不依赖于具体运行平台和编程语言
- 高效自动化解析和生成
- 压缩比例高
- 可扩展、兼容性好


**gRPC与protobuf**

gRPC使用 protobuf 作为IDL来定义数据结构和服务。 可以定义数据结构，也可以定义rpc 接口。
然后用proto编译器生成对应语言的框架代码。

- 定义数据结构 ： 生成对象的 序列化 代码
- 定义rpc接口 ： 生成 gRPC服务端、客户端响应的代码





## protobuf 基本数据类型

https://developers.google.com/protocol-buffers/docs/proto#scalar


## 数据结构定义

user.proto
```
syntax = "proto2";
// syntax = "proto3";

package user;
// option go_package = "protos_golang/user";

import "common.proto";

message User {
  required int32 id = 1;
  string name = 2;
  uint32 age = 3;
  
  enum Flag {
    NORMAL = 0;
    VIP = 1;
    SVIP = 2;
  }
  optional FLag flag = 4 [default = NORMAL];
  repeated int32 friends_ids = 5;
  reserved 6, 7, 8;
  
  message Command {
      int32 id = 1;
      oneof cmd_value {
         string name = 2;
         int32 age = 3;
      }
  }
  
  Command cmd = 9;
  map<int32, string> tags = 10;
  common.Flag feature = 11;
}
```

**package**

package声明符，用来防止不同的消息类型有命名冲突。
生成的代码将会包含再package(go等语言)或者命名空间(c++, java等)中。

`option go_package = "protos_golang/user";`   
`$LANGUAGE_package` 是指定生成的代码的import path和package。


**import**

要导入其他.proto文件的定义，在文件中添加一个导入声明。  
使用导入proto的类型 `package名字.结构名` 来使用导入proto的类型。  
如上面`common.Flag` 

**分配字段编号**

每个字段都有唯一的一个数字标识符。这些标识符是用来在消息的二进制格式中识别各个字段的。  
为了保证向后兼容，一旦开始使用就不要再改变。 



**文件版本申明**

`syntax = "proto2"; ` 指定使用proto2语法  
`syntax = "proto3"; ` 指定为proto3语法  


**标识符修饰符**

required 和 optional 是proto2的语法，proto3已经不支持。  
proto3中所有的字段都是optional的。[具体原因见](https://github.com/protocolbuffers/protobuf/issues/2497) 

- required : 必须字段。
- optional ：可选字段。
- repeated ：数组类型字段。
- reserved ：保留字段。指出这些字段编号已经删除，不要再重用这些编号了。因为如果这些编号被重新定义成其他类型，那么对于旧版本的protobuf数据，会导致解码错误。


**枚举**

与数据结构中 enum 类似。字段编号从0开始。


**oneof**

oneof与数据结构联合体(UNION)类似，一次最多只有一个字段有效。

**map**

map 类型则可以用来表示键值对。  
key_type 可以是任何 int 或者 string 类型，float、double 和 bytes除外


**嵌套类型**

可以在消息类型中定义其他消息类型


## 服务定义

```
syntax = "proto2";

import "user.proto";

service UserService {
// rpc interface
    rpc GetUserInfo(UserRequest) returns (UserResponse) {}
}

message UserRequest {
    uint32 id = 1;
}

message UserResponse {
    user.User user = 1;
}
```

如果在 .proto 文件中定义了 RPC 服务接口， 编译器将使用生成服务接口代码和 stubs。

`import "user.proto";` 导入user结构定义的proto文件。



## 插件

protoc编译器通过插件机制实现对不同语言的支持。  
protoc会先查找是否有内置的语言插件，如果没有，则会去查找系统中是否存在`protoc-gen-$LANGUAGE` 的插件。  
例如：
如果指定`--go_out`参数，那么protoc会查询是否有内置的`go`插件，如果没有则继续查询系统中是否存在`protoc-gen-go`的可执行程序，再通过插件来生成相关的语言代码。



**插件运行流程：**
- protoc 启动 protoc-gen-xx
- 将`CodeGeneratorRequest`的protobuf二进制传入到 protoc-gen-xx的标准输入
  - protoc-gen-xx读取标准输入再反序列化成`CodeGeneratorRequest`
  - 遍历`CodeGeneratorRequest`的`FileDescriptorProto`数组，其描述了proto文件的语法树
  - 将`FileDescriptorProto`编译成语言源码
  - 生成`CodeGeneratorResponse`对象输出到标准输出
- protoc根据protoc-gen-xx的标准输出再生成源码文件



[plugin.proto](https://github.com/protocolbuffers/protobuf/blob/master/src/google/protobuf/compiler/plugin.proto)定义了`CodeGeneratorRequest` 和 `CodeGeneratorResponse`，是protoc与插件交互的对象。  

[descriptor.proto](https://github.com/protocolbuffers/protobuf/blob/master/src/google/protobuf/descriptor.proto)描述的是一个`.proto`文件的语法树










# gRPC 原理

## 概念


![image](https://grpc.io/img/landing-2.svg)


gRPC 定义服务，服务包含远程调用的方法。  
在服务器端，服务器实现rpc接口并运行一个gRPC服务器来处理客户端请求。   
在客户端，客户端有一个"存根stub"，提供与服务器相同签名的方法，来处理客户端请求的编码、解码等，再将请求转发到服务器端，这样客户端调用rpc方法就像调用本地函数一样。  




## 实现


gRPC把HTTP2的steam identifier当作请求ID，每一次请求都发起一个新的stream。

请求的方法、响应的状态码等都放在HEADER frame中。  
而请求内容和响应内容由protobuf序列化后使用DATA frame中。


### 请求

Request主要由 Request-Headers 和 Data 以及 EOS (END_STREAM)组成。  

如下图：

![image](https://github.com/ikenchina/img1/raw/master/1/network/rpc/grpc/debug/wireshark/grpc_request_stream_decoded_wireshark.png)


**Request-Headers**  

Request-Headers 由 HEADERS 和 CONTINUATION frames 组成。  
如果Flags有设置标志位`END_HEADERS`则代表Request-Headers结束。  


Request-Headers 主要有 `Call-Definition` 以及 `Custom-Metadata` :
- Call-Definition : 包括 Method, Scheme, Path, TE, Authority, Timeout, Content-Type ,Message-Type, Message-Encoding, Message-Accept-Encoding, User-Agent
- Custom-Metadata : 应用层自定义的任意 key-value，key 不要使用gRPC保留的key前缀字符 `grpc-` 。


**Data**

请求体，由一个或多个 Data frame组成。  
如果Flags有设置标志位`END_STREAM`则代表Data结束，请求结束。 


**request格式大致如下**

```
# request-headers 

HEADERS (flags = END_HEADERS)
:method = POST
:scheme = http
:path = /user.UserService/GetUserInfo
:authority = localhost:50000
grpc-timeout = 999127u
content-type = grpc-go/1.20.0-dev

## 自定义metadata
service : test_client
traceid : xxxx

# data
DATA (flags = END_STREAM)
<Length-Prefixed Message>
```



### 响应

Response 主要由 Response-Headers 和 Data 以及 Trailers 组成。  
如果遇到了错误，也可以直接返回 Trailers-Only。


如下图：

![image](https://github.com/ikenchina/img1/raw/master/1/network/rpc/grpc/debug/wireshark/grpc_response_stream_decoded_wireshark.png)


**Response-Headers**

Response-Headers 包含 : HTTP-Status, Message-Encoding, Message-Accept-Encoding, Content-Type, Custom-Metadata等。

**Data**

响应体，由一个或多个 Data frame组成。  
如果Flags有设置标志位`END_STREAM`则代表Data结束。 

**Trailers**

Trailers-Only 包含 HTTP-Status, Content-Type, Trailers等。

Trailers 包含 Status, Status-Message, Custom-Metadata等。

Trailers作用主要是给响应包含一些额外的动态生成的信息。  
如：消息body发送后，再发送一些信息 如数字签名，后处理状态等


格式大致如下：
```
# response-headers

HEADERS (flags = END_HEADERS)
:status = status: 200 
content-type = application/grpc

## 自定义metadata
service: server_test
spanid: xxxx


# data
DATA
<Length-Prefixed Message>

# headers
HEADERS (flags = END_STREAM, END_HEADERS)
grpc-status: 0

## trailers 自定义metadata
timestamp: 1560656283730441829

```


**Status code**

[HTTP状态码对应的gRPC状态码](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md)




## gRPC通信方式

gRPC有四种通信方式: 

1、 unary RPC 

一般的rpc调用，客户端发送一个请求对象，然后等待服务端返回一个响应对象 

```
# 获取用户信息
# proto
rpc GetUserInfo (UserRequest) returns (UserResponse) {}
```


2、 Server-side streaming RPC 

服务端流式rpc 

客户端发起一个请求到服务端，服务端返回一段连续的数据流响应。

```
# 获取一个用户的所有地理位置历史记录
# proto
rpc UserLocationsStream(UserRequest) returns (stream LocationsResponse) {}
```



3、 Client-side streaming RPC 

客户端流式rpc 

客户端将一段连续的数据流发送到服务端，服务端返回一个响应。

```
# 客户端将所有数据备份到服务端
# proto
rpc BackupStream(stream BackupRequest) returns (BackupResponse) {}
```

4、 Bidirectional streaming RPC 

双向流式rpc 

客户端将连续的数据流发送到服务端，服务端返回交互的数据流。

```
# 在线聊天
# proto
rpc LiveChat(stream Message) returns (stream Message) {}
```



## 配置


**waitForReady**

发送请求时，如果connection没有ready，则会一直等待connection ready 或直到超时(达到deadline)。 
也常称为`fail fast`。


**timeout**

请求超时时间。  
如果超时，则会中止请求且返回DEADLINE_EXCEEDED 错误。


**maxRequestMessageBytes**

请求体的最大payload size(没有压缩的)。  
如果客户端请求大于此值的请求会返回RESOURCE_EXHAUSTED错误。 


**maxResponseMessageBytes**

响应体的最大payload size(没有压缩的)。  
如果服务端响应大于此值，响应将发送失败。且客户端会得到RESOURCE_EXHAUSTED错误。 



---


# gRPC 实践

实践部分以go语言进行demo


## 环境

**安装protoc**

mac
```
brew install protobuf
```

linux
```
PROTOC_ZIP=protoc-3.5.1-linux-x86_64.zip
curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.5.1/$PROTOC_ZIP

sudo unzip -o $PROTOC_ZIP -d /usr/local bin/protoc
sudo unzip -o $PROTOC_ZIP -d /usr/local include/*
rm -f $PROTOC_ZIP
```

**golang的protobuffers插件**
```
go get -u github.com/golang/protobuf/{protoc-gen-go,proto}

```

## Coding

### 定义proto文件

```
syntax = "proto3";
//package user;
option go_package = "protos_golang/user";

message User {
  int32 id = 1;
  string name = 2;
  uint32 age = 3;
  enum Flag {
    NORMAL = 0;
    VIP = 1;
    SVIP = 2;
  }
  repeated int32 friends_ids = 5;
  reserved 6, 7, 8;
  message Command {
      int32 id = 1;
      oneof cmd_value {
         string name = 2;
         int32 age = 3;
      }
  }
  Command cmd = 9;
  map<int32, string> tags = 10;
}

service UserService {
// rpc interface
    rpc GetUserInfo(UserRequest) returns (UserResponse) {}
}

message UserRequest {
    uint32 id = 1;
}

message UserResponse {
    User user = 1;
}
```

### 生成代码

**生成代码的导入路径和包名**
```
## protos_golang ： 生成代码的路径
## user : golang package 名
option go_package = "protos_golang/user";
```


**目标代码**

- 如果包含rpc接口：则需要指定插件`plugins=grpc`
- `--go_out=.` ： 生成的代码在`当前目录`; 也可以指定其他目录，如:`--go_out=/tmp`
- 代码路径 ： 
  - 如果.pb中指定了`go_package` : 代码路径是 `./$go_package/user.pb.go`
  - 如果.pb中没有指定`go_package` : 则代码路径是 `./pb/user.pb.go`

```
protoc --go_out=plugins=grpc:. pb/user.proto

# 如果没有rpc定义
protoc --go_out=. pb/user.proto
```



### 服务端


```
package main

import (
	"context"
	"log"
	"net"

    "google.golang.org/grpc"
    "google.golang.org/grpc/reflection"
    
	pb "testgrpc/protos_golang/user"
)

const (
	port = ":50000"
)

// grpc server
type server struct{}

// 实现gRPC接口
func (s *server) GetUserInfo(ctx context.Context, in *pb.UserRequest) (*pb.UserResponse, error) {

	return &pb.UserResponse{
		User: &pb.User{
			Name: "test_user",
		},
	}, nil
}

// 拦截器，简单打印下日志
func LogUnaryInterceptorMiddleware() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (r interface{}, err error) {
		r, err = handler(ctx, req)

		fmt.Printf("fullMethod(%s), errCode(%v)\n", info.FullMethod, err)
		return r, err
	}
}


func main() {
	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

    // 拦截器
    options := grpc.UnaryInterceptor(LogUnaryInterceptorMiddleware())
	s := grpc.NewServer(options)
	
	// 注册服务器实现
	pb.RegisterUserServiceServer(s, &server{})
	
	// 注册服务端反射
	reflection.Register(s)
	
	// 启动服务器
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}

```




### 客户端
```

package main

import (
	"context"
	"log"
	"time"

	"google.golang.org/grpc"

	pb "testgrpc/protos_golang/user"
)

const (
	address = "localhost:50000"
)

func main() {

	conn, err := grpc.Dial(address, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewUserServiceClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	r, err := c.GetUserInfo(ctx, &pb.UserRequest{})
	if err != nil {
		log.Fatalf("fatal: %v", err)
	}

	log.Printf("response: %s", r)
}

```



### 调试

为了方便调试服务端，所以服务端需要支持reflection功能。  
```
reflection.Register(grpcServer)
```


两款比较著名的调试工具：
- [grpc_cli](https://github.com/grpc/grpc/blob/master/doc/command_line_tool.md : 官方的
- [grpcurl](https://github.com/fullstorydev/grpcurl) : go的，安装简单



**列出服务端注册的service**

如果没有配置好公钥和私钥文件，也没有忽略证书的验证过程，则需要加`-plaintext`
```
$ grpcurl -plaintext localhost:50000 list 
grpc.reflection.v1alpha.ServerReflection
user.UserService
```

**列出服务的接口**

```
$ grpcurl -plaintext localhost:50000 list  user.UserService
user.UserService.GetUserInfo
```

**获取接口的签名**

```
$ grpcurl -plaintext localhost:50000 describe user.UserService.GetUserInfo
user.UserService.GetUserInfo is a method:
rpc GetUserInfo ( .user.UserRequest ) returns ( .user.UserResponse );
```

**获取类型信息**

```
$ grpcurl -plaintext localhost:50000 describe .user.UserRequest
user.UserRequest is a message:
message UserRequest {
  uint32 id = 1;
}

```

**调试接口**

请求体以json的形式描述类型。 

```
$ grpcurl -plaintext -d '{"id":1}'   localhost:50000  user.UserService.GetUserInfo
{
  "user": {
    "name": "test_user"
  }
}
```




## go gRPC 生态

### 服务组件


**上下文信息传递**

rpc客户端将上下文信息传递给服务端。  
链路调用信息，服务信息，认证信息等等。

[官方实现](https://godoc.org/google.golang.org/grpc/metadata)


**服务器反射**

服务端反射协议， 可以用途于:
- 服务端调试 : grpcurl 工具就是用reflection协议来进行服务端调试的。可以list出服务端的接口定义，以及命令行构造请求进行调试。
- 运行时构造gRPC请求 ：客户端可以运行时根据反射的接口定义构造请求。


[官方实现](https://godoc.org/google.golang.org/grpc/reflection)




**负载均衡**

客户端负载均衡器


[官方实现](https://godoc.org/google.golang.org/grpc/balancer)


**认证**  

gRPC主要的两种认证方式：
- 基于SSL/TLS认证方式
- Token认证方式

两种方式可以同时应用


[官方实现](https://godoc.org/google.golang.org/grpc/credentials)  实现了几种认证方式：
- alts  
- google 
- oauth
- 自定义认证方式


[go-grpc-middleware的实现](https://godoc.org/github.com/grpc-ecosystem/go-grpc-middleware/auth)



**健康检查**


服务端提供一个`Check`接口返回其状态信息。  
客户端调用此接口获取到服务健康状态，是否可以继续提供服务。


[官方实现](https://godoc.org/google.golang.org/grpc/health)


**keepalive**

定期发送HTTP/2.0 pings帧来检测 connection 是否存活，如果断开则进行重新连接。  
与健康检查区别在于keepalive是检查connection而健康检查是检查服务是否可用。


[官方实现](https://godoc.org/google.golang.org/grpc/keepalive)


**naming**

命名解析。  
通过服务命名来获取服务相关的信息来达到服务发现目的。  

与balancer结合使用来实现进程内负载均衡与服务发现。  

[官方实现](https://godoc.org/google.golang.org/grpc/naming)



**限流**

限制流量来保护服务端以防止服务过载。  

可以在客户端，balancer，服务端 进行限流。

[go-grpc-middleware实现服务端限流](https://godoc.org/github.com/grpc-ecosystem/go-grpc-middleware/ratelimit)




**recovery**

将服务内部的错误转换成gRPC错误码。  

[go-grpc-middleware实现](https://godoc.org/github.com/grpc-ecosystem/go-grpc-middleware/recovery) ： recover go的panic， 并转换成gRPC错误。




**重试**

客户端对于返回某些gRPC错误码的请求进行重试。

[go-grpc-middleware](https://godoc.org/github.com/grpc-ecosystem/go-grpc-middleware/retry)




**tracing**

在链路上下文携带tracing信息，以及将信息以opentracing的规范发送给`分布式链路分析服务`。

tracing信息包含traceid,spanid,请求时间,错误信息,日志等等。  
如：通过设置客户端spanid为服务端spanid的parent_spanid，这样就能知道是客户端调用了服务端rpc请求。


[go-grpc-middleware实现opentracing的middleware](https://godoc.org/github.com/grpc-ecosystem/go-grpc-middleware/tracing/opentracing)

[open-tracing](https://opentracing.io/docs/)




### 微服务框架、组件

[go-kit](https://github.com/go-kit) : 微服务组件  
[micro](https://github.com/micro) : 微服务框架  
[go-chassis](https://github.com/go-chassis/go-chassis) : 华为开发的go微服务框架  
[go-grpc-middleware](https://github.com/grpc-ecosystem/go-grpc-middleware) : 服务端和客户端的一些中间件，认证、日志、分布式追踪跟重试等  
[grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) ：一个 protoc 的插件，可以将 gRPC 接口转换为对外暴露 RESTful API 的工具，同时还能生成 swagger 文档  





### gRPC 与 负载均衡

**进程内LB(Balancing-aware Client)**


需要实现：
- 服务注册
- 健康检查
- 服务发现
- 负载均衡

缺点：
- 开发成本：要实现上述功能
- 维护成本：不同语言栈的sdk维护与升级



[官方](https://godoc.org/google.golang.org/grpc/balancer)已经提供接口来实现进程内的负载均衡。同时结合服务发现，健康检查一起使用。




**集中式LB(Proxy Model)**

proxy 实现服务发现，健康检查，负载均衡等等。  
还方便做限流等控制和其他统一控制策略。

缺点：
- 单点问题
- 多一层性能开销
- 不方便调试


***Nginx***

> Nginx(1.13.10已经支持gRPC) 




```
upstream grpcservers {
    server localhost:50000;
    server localhost:50001;
}

server {
    listen 9000 http2;

    # router
    location /user.UserService {
        grpc_pass grpc://grpcservers;
        error_page 502 = /error502grpc;
    }
    
    # 将默认错误页面更改成gRPC状态码
    location = /error502grpc {
        internal;
        default_type application/grpc;
        add_header grpc-status 14;
        add_header grpc-message "unavailable";
        return 204;
    }
}
```

[nginx gRPC module](https://nginx.org/en/docs/http/ngx_http_grpc_module.html)




**独立LB进程(External Load Balancing Service)**

在主机上部署独立的LB进程，来实现服务发现，健康检查，负载均衡等功能。  
不用对于不同语言维护不同sdk版本；  
常常用于微服务service mesh。

缺点：
- 单点问题：但是只影响本机
- 不方便调试

常用的组件：  
- [Istio](https://istio.io/)  
- [Envoy](https://github.com/lyft/envoy)







---

# gRPC 生态环境

## 组件

 grpc 只是实现了 RPC 核心功能，缺少很多微服务的特性（服务注册发现、监控、治理、管理等），而基于 HTTP/2 相对来说比较容易进行扩展。
 
[grpc-ecosystem](https://github.com/grpc-ecosystem) 上有一些比较优秀的外围组件来完善gRPC的生态体系  


[awesome-grpc](https://github.com/grpc-ecosystem/awesome-grpc) 收集了一些优秀的gRPC项目   




## grpc 文档与交流

**文档**

- 官网文档 : https://grpc.io/docs/ 
- github 上 grpc 仓库下的 doc ： https://github.com/grpc/grpc/tree/master/doc
- 博客 : https://grpc.io/blog/

**交流**

https://grpc.io/community/ 交流的方式有：
- 邮件列表
- Gitter
- Reddit
- Meetup Group 










# 参考

[grpc.io](https://grpc.io/docs/guides)

[developers.google.com](https://developers.google.com/protocol-buffers/docs)

[gRPC github doc](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#Requests)

[http2 specs](https://tools.ietf.org/html/rfc7540)    
or   
[github http2 spec](http://http2.github.io/http2-spec/#StreamPriority)
