---
layout: post
category: "2020"
title:  "TreadMarks: 基于工作站网络的共享内存计算"
tags: [分布式]
date: 2020-04-01
---

> TreadMarks: 基于工作站网络的共享内存计算<!-- more -->  





　　　　　　论文: TreadMarks: Shared Memory Computing on Networks of Workstations

　　　　　　　Christiana Amza, Alan L. Cox, Sandhya Dwarkadas, Pete Keleher,    
　　　　　　　Honghui Lu, Ramakrishnan Ra jamony, Weimin Yu and Willy Zwaenepoel    
　　　　　　　　　　　　　Department of Computer Science    
　　　　　　　　　　　　　　　　Rice University    



# 摘要（Abstract）

TreadMarks通过为应用程序提供共享的内存抽象来支持基于工作站网络上的并行计算。共享内存有助于从顺序程序转换成并行程序，因为大多数数据结构都可无需做更改。 只需要添加同步操作。 我们会讨论TreadMarks中用于提供有效的共享内存技术，并讨论了两个主要应用程序的经验，即混合整数编程和遗传连锁分析。

# 1 介绍（ Introduction）

高速网络和快速提高的微处理器性能使工作站的网络成为越来越有吸引力的并行计算工具。通过仅仅依靠廉价硬件和软件，工作站网络可以以相对较低的成本提供并行处理。可以将工作站网络的多处理器实现成处理器组[17]，这是许多专用于提供计算周期的处理器。或者，它也可以由一组动态变化的机器组成，在这些机器上利用空闲周期执行长时间运行的计算[14]。在后一种情况下，（硬件）成本基本上为零，因为许多组织机构已经拥有广泛的工作站网络。在性能方面，处理器速度，网络带宽和延迟的改进使联网的工作站能够为越来越多的应用程序提供接近或超过超级计算机的性能。我们的立场不是让这种松耦合的多处理器设计使更紧密耦合的设计过时。
尤其是，更低延迟和更高带宽的这些紧耦合的设计能有效执行对同步和通信要求更加严格的应用程序。但是，我们认为网络技术和处理器性能的进步将极大地扩展可以在工作站网络上有效执行的应用程序的种类。

　　在论文中，我们会讨论使用TreadMarks分布式共享内存（DSM）系统在工作站网络上进行并行计算的经验。DSM允许进程假定全局共享的虚拟内存，即使它们运行的节点并没有在物理上共享内存[13]。图1举例说明了一个DSM系统，该系统由N个联网的工作站组成，每个工作站都有自己的内存，并通过网络连接起来。DSM软件提供了全局共享内存的抽象，每个处理器都可以访问任何数据项，而程序员不必担心数据在哪里或如何获取。相反，在基于工作站网络的“本地”编程模型中，程序员必须确定处理器何时需要进行通信，与谁进行通信以及要发送什么数据。对于具有复杂数据结构和复杂并行化策略的程序，这可能成为艰巨的任务。在DSM系统上，程序员可以专注于算法开发，而不是管理分区的数据集和数据传输。除了易于编程之外，DSM还提供了与（硬件）共享内存多处理器相同的编程环境，从而允许在两种环境之间进行移植。最后，DSM考虑到在网络环境中无缝集成共享内存的多处理器工作站。本文描述的实际系统TreadMarks [7]，在Unix工作站上以用户级别运行。不需要进行内核修改或使用特权，并且使用标准Unix编译器和链接器。实现DSM系统的挑战在于确保共享内存抽象不会导致大量通信。TreadMarks中使用了多种技术来应对这一挑战，包括lazy release consistency(延迟释放一致性)[6]和多写协议[3]。本文首先会描述TreadMarks提供的应用程序编程接口（第2节），接下来，我们会讨论实现方面的挑战。（第3节）以及用于应对这些挑战的技术（第4和第5节）。我们在第6节中会简要的描述TreadMarks的实现，并通过讨论我们在混合整数编程和遗传连锁分析（第7节）这两个大型应用程序中的经验来证明其效率。最后，我们在第8节中讨论相关工作，并在第9节中提供一些结论和指导，以及进一步的工作。

![图１](https://github.com/ikenchina/img1/raw/master/1/treadmarks/arch1.png)

　　　　　　　　　　　　　　　　　图１　分布式共享内存

# 2 共享内存编程（Shared Memory Programming）

## 2.1 应用程序编程接口（Application Programming Interface）

TreadMarks API简洁但功能强大（有关C语言接口，见图2）。它提供了用于进程创建和销毁，同步以及共享内存分配的功能。我们专注于同步原语。 共享内存会引起数据争用。当不同进程以程序员不希望的方式交错对共享变量访问时，就会发生数据竞争。例如，假设一个进程写入共享记录的多个字段，而另一个进程尝试读取这些相同的字段。第二个进程很有可能读取新写入的值，但也有可能在第一个进程写入新值前读取到旧值。通常不希望发生这种情况。 为了避免这种情况，共享内存并行程序包含同步操作。 在这种特殊情况下，将使用锁来允许每个进程对记录的独占访问。

TreadMarks提供了两种同步原语：barrier(屏障)和exclusive locks(排他锁)。进程通过调用 Tmk barrier() 来等待屏障。屏障是全局的：调用进程会被暂停，直到系统中的所有进程到达同一屏障为止。进程调用Tmk lock来获取锁，然后调用Tmk release来释放锁。当另一个进程持有该锁时，任何进程都无法获取该锁。同步原语的这种特定选择跟TreadMarks的设计没有任何关系；以后可能会增加其他原语。 我们通过两个简单的应用程序演示了这些以及其他TreadMarks原语的用法。



## 2.2 两个简单的示例（Two Simple Illustrations）

图3和图4说明了TreadMarks API在Jacobi迭代和解决旅行商问题（TSP）中的使用。 我们很清楚这些示例代码的过于简单。 但在这里仅用于演示目的。 实际应用将在第7节中讨论。

　　Jacobi是一种求解偏微分方程的方法。我们的示例遍历二维数组。在每次迭代期间，每个矩阵元素都会更新为其最近元素的平均值（上方，下方，左侧和右侧）。Jacobi使用临时数组存储每次迭代期间计算的新值，以避免元素的旧值在其被临近元素使用之前覆盖。在并行版本中，为所有处理器分配的数量大致相等的行。 边界上的行由两个相邻进程共享。

　　图3中的TreadMarks版本使用两个数组：一个网格和一个临时数组。网格的保存在共享内存中，而临时的是每个进程专有的。网格由进程0分配和初始化。Jacobi中的同步是通过屏障实现的。 Tmk barrier(0) 确保在开始计算之前，进程0的初始化对所有进程可见。Tmk barrier(1) 确保所有进程在上一次迭代中完成读取值之前，不会有进程会覆盖网格中的任何值。Tmk barrier(2) 可防止当前迭代计算中的所有网格的值被设置前，没有任何进程可以开始下一次迭代。

　　旅行商问题（TSP）是查找从指定城市开始，经过地图上所有其他城市恰好一次并返回原始城市的最短路径。使用了一种简单的分支定界算法。每次局部旅行一次就扩展一个城市。如果局部旅行的长度加上路径剩余部分的下限大于当前最短旅行路径的话，则不会在进一步进行局部旅行了，因为他不会导致比当前最短路径更短的路径了。

　　该程序维护一个局部旅行的列队，保持最短的局部旅行在列队最前面。它不断往列队中添加可能最优的局部旅行，直到从列队的开头开始找到一个比阈值长的路径为止。然后程序将它从列队中移除，并尝试剩余程序的所有排列。最终，它将比较当前路径和包含此路径的最短路径，且如果有必要的话就更新当前最短路径。列队和当前最短路径是共享的，通过锁来保护对他们的访问。



```
/* the maximum number of parallel processes supported by TreadMarks */
#define TMK_NPROCS
/* the actual number of parallel processes after Tmk_startup */
extern unsigned Tmk_nprocs;
/* the process id, an integer in the range 0 ... Tmk_nprocs - 1 */
extern unsigned Tmk_proc_id;
/* the number of lock synchronization objects provided by TreadMarks */
#define TMK_NLOCKS
/* the number of barrier synchronization objects provided by TreadMarks */
#define TMK_NBARRIERS
/* Initialize TreadMarks and start the remote processes */
void Tmk_startup(argc, argv) int argc; char **argv;
/* Terminate the calling process. Other processes are unaffected. */
void Tmk_exit(status) int status;
/* Block the calling process until every other process arrives at the barrier. */
void Tmk_barrier(id) unsigned id;
/* Block the calling process until it acquires the specified lock. */
void Tmk_lock_acquire(id) unsigned id;
/* Release the specified lock. */
void Tmk_lock_release(id) unsigned id;
/* Allocate the specified number of bytes of shared memory */
char *Tmk_malloc(size) unsigned size;
/* Free shared memory allocated by Tmk_malloc. */
void Tmk_free(ptr) char *ptr;

```

　　　　　　　　　　　图 2 TreadMarks C语言接口



```
#define M 1024
#define N 1024
float **grid;
float scratch[M][N];

Tmk_startup();

if (Tmk_proc_id == 0)
{
    grid = Tmk_malloc(M * N * sizeof(float));
    initialize grid;
}

Tmk_barrier(0);
length = M / Tmk_nprocs;
begin = length * Tmk_proc_id;
end = length * (Tmk_proc_id + 1);
for (number of iterations)
{
    for (i = begin; i < end; i++)
        for (j = 0; j < N; j++)
            scratch[i][j] = (grid[i - 1][j] + grid[i + 1][j] +
                             grid[i][j - 1] + grid[i][j + 1]) / 4;
    Tmk_barrier(1);
    for (i = begin; i < end; i++)
        for (j = 0; j < N; j++)
            grid[i][j] = scratch[i][j];
    Tmk_barrier(2);
}

```

　　　　　　　　　　　图 3 The TreadMarks Jacobi 程序







# 实现的挑战（Implementation Challenges）

提供内存一致性是DSM系统的核心：DSM软件必须以一种提供全局共享内存的方式在处理器之间移动数据。在李的原始IVY系统中[13]，虚拟内存硬件用于维护内存一致性。每个处理器的本地（物理）存储器形成全局虚拟地址空间的高速缓存（请参见图5）。如果一个页面不在本地处理器的内存中，则会产生缺页错误。DSM软件将该页面的最新副本从其远程位置导入本地内存，然后重新启动该过程。例如，图5显示了处理器1发生缺页错误，然后从处理器3的本地内存中复制需要页面的副本。IVY进一步将读取错误与写入错误区分开。发生读取错误时，页面将所有副本以只读方式进行复制，而发生写入错误时，所有现有副本都将无效，并且写的处理器保留唯一副本。

```
queue_type *Queue;
int *Shortest_length;
int queue_lock, tour_lock;
main()
{
    Tmk_startup();
    queue_lock = 0;
    tour_lock = 1;
    if (Tmk_proc_id == 0)
        Queue = Tmk_malloc(sizeof(queue_type));
    Shortest_length = Tmk_malloc(sizeof(int));
    initialize Heap and Shortest_length
        Tmk_barrier(0);
    Tmk_lock_acquire(queue_lock);
    Exit if queue is empty;
    Keep adding to queue
        until a long,
        promising tour appears at the head;
    Path = Delete the tour from the head;
    Tmk_lock_release(queue_lock);
    length = recursively
    try
        all cities not on Path,
            find the shortest tour length
                Tmk_lock_acquire(tour_lock);
    if (length < *Shortest_length)
        *Shortest_length = length;
    Tmk_lock_release(tour_lock);
}

```

　　　　　　　　　　　图4 The TreadMarks TSP 程序



　　尽管很简单，但DSM的IVY实现可能产生大量通信。而在工作站网络上通信的成本很高。发送消息可能涉及到进入操作系统内核陷阱，中断，上下文切换以及可能经过多层网络协议的处理。因此，必须保持较少的消息的数量。 我们使用图3和图4的示例来说明IVY中的一些通信问题。

　　第一个问题与IVY的一致性模型有关，通常称为顺序一致性（sequential consistency） [9]。粗略地说，顺序一致性要求对共享内存的写入对于其他处理器“立即”变为可见。这就是为什么IVY在写入共享内存之前发送无效消息的原因。在许多情况下，顺序一致性提供了过强的保证。 例如，思考下图4中TSP中最佳巡回的更新及其长度。在IVY中，这两个共享内存更新将导致无效信息发送到所有其他的缓存包含这些变量的页面的处理器。 但是，只会在有相应锁保护的临界区内访问这些变量，因此仅将无效发送给获取锁的下一个处理器就足够了，并且仅在获取锁时才发送。

　　第二个问题涉及到潜在的伪共享的问题。当位于同一个页面的两个或两个以上不相关的数据对象由不同的处理器并发写入时，就会导致伪共享，从而导致该页在处理器之间像乒乓球一样来回移动。由于一致性单元很大（虚拟内存页），所以伪共享是一个潜在的严重问题。图6展示了Jacobi中网格数组可能的页面布局。 当两个处理器都更新其网格数组的一部分时，它们正在同时写入同一页面，并导致该页面在处理器间来回移动多次。





![图５](https://github.com/ikenchina/img1/raw/master/1/treadmarks/ivh1.png)

　　　　　　　　　　　图５　IVH DSM系统操作


# 4 懒惰更新释放一致性（Lazy Release Consistency）



## 4.1 释放一致性（Release Consistency）

释放一致性[5]是一个宽松的内存一致性模型。它不能始终保证一致性。 对共享内存更新的传播可能会延迟一段时间。这样，释放一致性实现可以将多个更新消息合并为单个消息，从而减少消息的数量。但是，通过在某些同步操作中强制执行一致性，至少对于正确同步的程序而言，对程序员屏蔽了潜在的不一致性。我们都在直观层面上讨论这些问题。关于更详细的说明，读者可以参考Gharachorloo 等人的论文

　　释放一致性的直觉如下。并行程序不应出现数据竞争，因为这会导致不确定的结果。因此，必须充分的使用同步来防止数据竞争。更具体地说，在对共享内存的两个冲突性访问之间必须存在同步（如果两个访问相同的内存位置，并且其中至少一个是写操作，则这两个访问是冲突性的）。由于存在这种同步，因此DSM系统可以延迟发送从一个进程到另一个进程的更新，直到发生这样的同步事件为止，因为只有执行了同步操作，第二个进程才会访问数据。对于没有数据竞争的程序，顺序一致性和释放一致性的结果是相同的。

　　我们将通过第2节中的Jacobi和TSP示例来说明这个原理。在Jacobi中，执行barrier 1 后才进行写共享内存操作，此时将新计算的值从临时数组复制到网格数组中。执行barrier 2时计算阶段才结束。执行barrier 2是为了避免在所有新值被写入网格数组前进程就开始下一次迭代。不管是什么存储模型，都必须需要barrier来确保正确性。但是，它的存在使我们可以推迟网格数组元素新值的传播，直到遇到更低的barrier。

　　在TSP中，任务队列是主要的共享数据结构。处理器从队列中获取任务并对其进行处理，也会创建新的任务。 这些新创建的任务将插入队列。任务队列结构的更新需要对共享内存进行一系列的写入，例如其大小，位于队列开头的任务等。原子地对任务队列数据结构进行访问是为了保证程序的正常运行。一次仅允许一个处理器访问任务队列数据结构。这些保证通过在操作前加锁，操作后解锁来实现。因此只有获得锁的进程才能访问数据结构，也无须立即将更新传播给其他进程。这些处理器需要首先获得锁。因此在获得锁的时候传播数据结构的更新就可以了。

　　这两个示例说明了释放一致性的基本原理。在共享内存的并行程序中引入了同步，以防止进程在同步操作完成之前查看某些内存。由此得出结论，在同步操作完成之前，不必传播那些内存操作的值。相反，顺序一致性会立即更新每个远程内存。 释放一致性需要少得多的消息，并导致更少的消息到达延迟。

　　程序员不必对此太在意。 如果程序没有数据竞争，则它的行为就好像在普通的共享内存系统上执行一样，其条件是：所有同步都必须使用TreadMarks提供的原语来完成。 否则，TreadMarks无法知道何时应该让共享内存保持一致性。



![图6](https://github.com/ikenchina/img1/raw/master/1/treadmarks/false_sharing1.png)

　　　　　　　　　　　　图６　Jacobi的伪共享例子



## 4.2 懒惰更新释放一致性（Lazy Release Consistency）

TreadMarks使用懒惰更新释放一致性算法[6]来实现释放一致性。粗略地说，懒惰更新释放一致性在获取锁时确保一致性，相反的，Munin早期实现的释放一致性在释放锁时实施一致性。懒惰更新释放一致性发送的消息更少。在锁释放时，Munin的释放锁的处理器发送缓存了修改数据的所有其他处理器。比较起来，在懒惰更新释放一致性中，一致性消息仅在锁的最后一个释放者和新获取者之间传播。

　　懒惰更新释放一致性（lazy release consistency）比急迫更新释放一致性（eager release consistency）更复杂一些。在释放后，Munin可以忘记释放的处理器在释放之前所做的所有修改。懒惰更新释放一致性不是这种情况，因为第三个处理器以后可能会获取锁并需要查看修改。在实践中，我们的经验表明，对于工作站网络而言，发送消息的成本很高，减少消息数量所带来的收益超过了更复杂的实现的成本。

# 5 多写协议（Multiple-Writer Protocols）

大多数硬件缓存和DSM系统使用单写程序协议。这些协议允许多个读同时访问同一页面，但是在执行任何修改之前，只允许一个写对页面进行修改。单写程序协议易于实现，因为给定页面的所有副本始终都是相同的，并且始终可以通过从当前具有有效副本的任何其他处理器中获取页面的副本来解决缺页错误。不幸的是，这种简单性通常以牺牲消息流量为代价的。 在写页面之前，所有其他副本都必须无效。如果其页面已失效的处理器仍在访问该页面的数据，这些失效则可能导致随后的访问丢失。

　　伪共享会由于无关访问之间的干扰而导致单写程序协议的性能更差。DSM系统通常比硬件系统遭遇更多的伪共享，因为它们以虚拟内存页面而不是高速缓存行的粒度跟踪数据访问。

　　顾名思义，多写协议允许多个写同时修改同一页面，并延后发送保证一致性的消息，尤其是直到同步发生为止

　　TreadMarks使用虚拟内存硬件来检测对共享内存页面的访问和修改。图7显示了如何使用保护故障（protection faults）来创建差异（diffs）。有效页面最初被写保护。 发生写操作时，TreadMarks会创建虚拟内存页的一个副本，或一个twin（双胞胎），并将其保存在系统空间中。当需要将修改发送到另一个处理器时，则将页面的当前副本与twin逐字比较，并将变化的字节保存到diff数据结构中。一旦创建diff后，twin将被丢弃。 除了处理器第一次访问页面外，其页面副本仅通过应用diff进行更新。 不再需要页面的新完整副本。

　　使用diff的主要好处是它们可用于实现多写协议，由于diff通常比页面小得多，因此它们还可显着降低总体带宽需求。



# ６ TreadMarks系统（The TreadMarks System）

TreadMarks完全以Unix上用户库的方式实现的。不需要修改Unix内核，因为现代Unix提供了在用户级别实现TreadMarks所需的所有通信和内存管理功能。用C，C++或者FORTRAN编写的程序可以用这些语言标准的编译器来编译和连接TreadMarks库。该系统是相对便携式的。 当前，它可以在SPARC，DECStation，DEC / Alpha，IBM RS-6000，IBM SP-1和SGI平台以及以太网和ATM网络上运行。 在本节中，我们简要描述如何实现TreadMarks的通信和内存管理。

　　TreadMarks使用Berkeley套接字接口实现了机器间通信。取决于底层的网络硬件，例如以太网或ATM，TreadMarks使用UDP / IP或AAL3 / 4作为消息传输协议。默认情况下，除非计算机通过ATM LAN连接，否则TreadMarks使用UDP / IP。AAL3 / 4是ATM标准规定的面向连接的最大努力交付协议（best-efforts delivery protocol）。 由于UDP / IP和AAL3 / 4都不保证可靠的传递，因此TreadMarks使用轻量，特定操作的用户级协议来确保消息到达。

　　TreadMarks发送的每个消息要么是请求消息要么是响应消息。TreadMarks发送的消息可能是显式调用TreadMarks库产生的或者是缺页错误产生的。一旦机器发送了请求消息，它将阻塞直到有一个请求消息或者预期的响应消息到达。为了请求处理的延迟最小化，TreadMarks使用SIGIO信号的处理程序来处理请求。消息到达用于接收请求消息的任何套接字都会产生SIGIO信号。由于AAL3 / 4是面向连接的协议，因此与其他每台机器都有一个相对应的套接字。为了确定哪个套接字处理请求，处理程序将执行select系统调用。处理程序收到请求消息后，将执行指定的操作，发送响应消息，然后返回到中断的进程。

　　为了实现一致性协议，TreadMarks使用mprotect系统调用来控制对共享页面的访问。尝试在共享页面上执行受限访问都会产生SIGSEGV信号。SIGSEGV信号处理程序检查本地数据结构以确定页面的状态。如果本地副本是只读的，则该处理程序从空闲页面池中分配一个页面，并执行bcopy来创建一个twin。最后，处理程序将访问权限升级到原来的页面并返回。如果本地页面无效，则处理程序执行一个过程（procedure）通过从最少的远程计算机集中获取对共享内存的必要更新。

![图7](https://github.com/ikenchina/img1/raw/master/1/treadmarks/diff1.png)

　　　　　　　　　　　　图７　DiffCreation

# 7 应用（Applications）

使用TreadMarks已实现了许多应用程序，并且一些基准测试的性能已在之前进行了报道[7]。在这里，我们描述最近使用TreadMarks实现的两个大型应用程序的经验。在本文作者的帮助下，顺序执行代码的作者将混合整数编程（mixed integer programming）和遗传连锁分析（genetic linkage analysis）这些应用程序从现有的顺序代码进行了并行处理。虽然很难量化所涉及的工作量，但已经证明为获得有效的并行代码而进行的修改的工作量相对很小，这将在本节的其余部分中演示。



## 7.1 混合整数编程（Mixed Integer Programming）

混合整数编程（MIP）是线性编程（LP）的一个版本。在LP中，在由一组线性不等式描述的区域中优化了目标函数。在MIP中，部分或全部变量被约束为只能用整数值（有时仅是0或1）。 图8显示了一个精确的数学公式，图9显示了一个简单的二维实例。

![图8](https://github.com/ikenchina/img1/raw/master/1/treadmarks/mip3.png)



　　　　　　　　　　　　　　图 8 混合整数编程问题(MIP) 



![图9](https://github.com/ikenchina/img1/raw/master/1/treadmarks/mip_two1.png)

​	　　　　　　　　　　　　　　　图 9 MIP二维实例





![图１０](https://github.com/ikenchina/img1/raw/master/1/treadmarks/branch_and_bound_mip2.png)

　　　　　　　　　　　　　　　　　图10 解决MIP问题的分支界定法



　　Lee等人实现了用于解决MIP问题的TreadMarks代码 [11]。该代码使用分支剪切法。首先将MIP问题简化为相应的LP问题。通常，这个LP问题的解决方案将为某些约束为整数的变量产生非整数值。下一步是选择这些变量中的一个，并分支出两个新的LP问题，一个问题具有 $x_{i} =  \left \lfloor x_{i} \right \rfloor$ 的附加约束，另一个具有 $x_{i} =  \left \lceil x_{i} \right \rceil$ 的附加约束（见图10）。慢慢地，该算法会生成此类分支的树。找到解决方案后，此解决方案便会在解决方案上建立界限。分支中的LP问题的解决方案产生的结果低于此边界则无需再进入下一步了。为了加快此过程，该算法使用一种称为`plunging`的技术，本质上是对树进行深度优先搜索，以找到整数解并尽快建立边界。最后一种感兴趣的改进的算法是`cutting planes`的使用。 这些是添加到LP问题的附加约束，以加强对整数问题的描述。

　　该代码用于解决MIPLIB库中的所有51个问题。该库包括航空人员调度，网络流量，工厂位置，机队调度等方面的代表性示例。图11显示了在8台运行Ultrix 4.3且通过100Mbps Fore ATM交换机连接的DecStation-5000 / 240机器的网络上获得的加速，这些问题的顺序运行时间超过2,000秒。对于大多数问题，加速几乎是线性的。 一个问题表现为超线性加速，这是因为并行代码命中了前期运行的解决方案，从而裁剪掉了大多数分枝定界树。对于另一个问题，几乎没有加速，因为在预处理步骤之后不久就找到了解决方案，此时还没有进行并行化。除了MIPLIB库中的问题外，该代码还可用于解决以前无法解决的多商品流问题[2]。 该问题在具有8个处理器的IBM SP-上花费的CPU时间为30天，并且还表现出接近线性的加速。



![图１１](https://github.com/ikenchina/img1/raw/master/1/treadmarks/miplib2.png)

　　　　　　　　　　　　　图11 MIPLIB库的结果



## 7.2 遗传连锁（Genetic Linkage）

遗传连锁分析是一种统计技术，使用家族谱系信息来绘制人类基因图谱并在人类基因组中定位疾病基因。生物学和遗传学的最新进展已提供了大量可用的遗传材料，使计算成为进一步研究的瓶颈。

　　在Mendelian经典的继承理论中，孩子的染色体接收父母一方每个染色体的一条链。考虑重组时，情况会有所不同。如果发生重组，则孩子的染色体链将包含父母染色体的每一条链中的每一条（见图12）。连锁分析的目的是推导我们寻找的基因与已知位置的基因之间发生重组的概率。 从这些概率可以计算出基因在染色体上的大概位置。

　　ILINK [4]是广泛使用的遗传连锁分析程序的一个并行版本，它是LINKAGE [10]程序包的一部分。ILINK将称为谱系的家谱作为输入，并增加了有关该家族成员的一些遗传信息。它计算重组概率θ的最大似然估计。从最上层来看，ILINK由一个优化θ的循环组成。在优化循环的每次迭代中，程序遍历整个谱系，一次遍历一个核心家庭，在已知家庭成员的遗传信息的情况下，计算当前θ的可能性。对于核心家庭的每个成员，该算法都会更新一系列条件概率，这些条件概率表示个体具有特定遗传特征的概率，其条件取决于θ和已经遍历的部分家谱。

　　通过以均衡负载的方式在可用处理器之间分配每个核心家庭的迭代空间，可以并行化上述算法。负载均衡是必不可少的，且依赖于阵列元素中表示的遗传信息的知识。另一个方式是拆分树，它未能产生良好的加速效果，因为大多数计算都发生在树的一小部分上（通常，这些节点靠近树的根部，他们表示已知遗传信息很少的已故者）。另外，无法并行评估不同的θ值，因为优化程序会从一个θ值顺序移至下一个θ值。

　　图13显示了使用ILINK为各种数据集获得的加速。数据集来自对真实的疾病基因定位的研究。对于运行时间较长的数据集，可以实现良好的加速。 对于最小的数据集BAD，由于通信与计算的比率变大，因此加速要少得多。



![图12](https://github.com/ikenchina/img1/raw/master/1/treadmarks/dna1.png)

　　　　　　　　　　　　　　图12 DNA重组

# 8 相关工作（Related Work）

本节的目标不是进行广泛的并行编程研究，而是以一个独特的示例说明替代性方案，并将最终的系统与TreadMarks进行比较。

消息传递（PVM）。 当前，消息传递是分布式存储系统的主要编程范例。便携式虚拟机（PVM）[15]是一种流行的消息传递软件。它允许将异构的计算机网络视为单个并发计算引擎。尽管PVM中的编程比底层机器的本机消息传递范例中的编程容易得多，并且可移植性强，但是应用程序程序员仍然需要编写代码来显式交换消息。TreadMarks的目标是减轻程序员的负担。 对于具有复杂数据结构和复杂并行化策略的程序，我们认为这是一个主要优势。

隐式并行（HPF）。 如HPF [8]中所示，隐式并行性依赖于用户提供的数据分布，编译器随后使用这些数据分布来生成消息传递代码。这种方法适用于数据并行程序，例如Jacobi。 动态并行性的程序，例如TSP，ILINK或MIP，很难在HPF框架中表达。

面向对象的并行计算（Orca）。Orca [16]和其他面向对象的并行计算系统一样没有为程序员提供共享的存储空间，而是支持对象的共享空间，每个对象都可以通过适当同步的方法进行访问。除了从编程的角度来看的优点之外，这种方法还允许编译器推断出某些优化方法，这些优化方法可用于减少通信量。缺点是，顺序程序中“自然”的对象通常不是正确的并行化对象，需要更多的更改才能获得有效的并行程序

硬件共享内存实现（DASH）。 另一种方法是在硬件中实现共享内存，对少量处理器使用侦听总线协议，或对大量处理器使用基于目录的协议（例如[12]）。我们使用这种方法来共享编程模型，但是我们的实现避免了昂贵的缓存控制器硬件。 另一方面，硬件实现可以有效地支持具有更细粒度并行性的应用程序。

条目一致性（Entry Consistency）（中途）。 条目一致性是另一种宽松的内存模型[1]。它要求所有共享数据都与同步对象相关联。当获取同步对象时，只传输与该同步对象关联的修改后的数据，从而进一步减少通信数据量。但是，条目一致性内存模型比释放一致性弱，这可能会使编程更加困难。

![图13](https://github.com/ikenchina/img1/raw/master/1/treadmarks/ilink.png)

　　　　　　　　　　　　　　　图13 ILINK结果　

# 9 总结和下一步工作（Conclusions and Further Work）

我们的经验表明，使用适当的实现技术，分布式共享内存可以为工作站网络上的并行计算提供有效的平台。多数应用程序移植到TreadMarks分布式共享内存系统上，几乎没有困难，并且性能良好。在下一步的工作中，我们打算尝试其他实际应用，包括地震建模代码。我们还在开发各种工具，以进一步减轻编程负担并提高性能。特别是，我们正在研究使用诸如支持预取的编译器，以及使用性能监视工具来消除不必要的同步。



# 引用（References）

[1] B.N. Bershad, M.J. Zekauskas, and W.A. Sawdon. The Midway distributed shared memory system. In Proceedings of the '93 CompCon Conference, pages 528-537, February 1993.
[2] D. Bienstock and O. Gumluk. Computational experience with a difficult mixed-integer multi-commodity  flow problem. To appear in Mathematical Programming, 1994.
[3] J.B. Carter, J.K. Bennett, and W. Zwaenepoel. Implementation and performance of Munin. In Proceedings of the 13th ACM Symposium on Operating Systems Principles, pages 152-164, October 1991.
[4] S. Dwarkadas, A.A. Schäffer, R.W. Cottingham Jr., A.L. Cox, P. Keleher, and W. Zwaenepoel. Parallelization of general linkage analysis problems. Human Heredity, 44:127-141, 1994.
[5] K. Gharachorloo, D. Lenoski, J. Laudon, P. Gibbons, A. Gupta, and J. Hennessy. Memory consistency and event ordering in scalable shared-memory multiprocessors. In Proceedings of the 17th Annual International Symposium on Computer Architecture, pages 15-26, May 1990.
[6] P. Keleher, A. L. Cox, and W. Zwaenepoel. Lazy release consistency for software distributed shared memory. In Proceedings of the 19th Annual International Symposium on Computer Architecture, pages 13-21, May 1992.
[7] P. Keleher, S. Dwarkadas, A. Cox, and W. Zwaenepoel. Treadmarks: Distributed shared memory on standard workstations and operating systems. In Proceedings of the 1994 Winter Usenix Conference, pages 115-131, January 1994.
[8] C. Koelbel, D. Loveman, R. Schreiber, G. Steele, Jr., and M. Zosel. The High Performance Fortran Handbook. The MIT Press, 1994.
[9] L. Lamport. How to make a multiprocessor computer that correctly executes multiprocess programs. IEEE Transactions on Computers, C-28(9):690{691, September 1979.
[10] G. M. Lathrop, J. M. Lalouel, C. Julier, and J. Ott. Strategies for multilocus linkage analysis in humans. Proc. Natl. Acad. Sci. USA, 81:3443-3446, June 1984.
[11] E. Lee, R. Bixby, W. Cook, and A.L. Cox. Parallelism in mixed integer programming. Submitted for publication, 1994.
[12] D. Lenoski, J. Laudon, K. Gharachorloo, A. Gupta, and J. Hennessy. The directory-based cache coherence protocol for the DASH multiprocessor. In Proceedings of the 17th Annual International Symposium on Computer Architecture, pages 148-159, May 1990.
[13] K. Li and P. Hudak. Memory coherence in shared virtual memory systems. ACM Transactions on Computer Systems, 7(4):321-359, November 1989.
[14] M. Litzkow, M. Livny, and M. Mutka. Condor - a hunter of idle workstations. In Proceedings of the 8th International Conference on Distributed Computing Systems, pages 104-111, June 1988.
[15] V. Sunderam. PVM: A framework for parallel distributed computing. Concurrency:Practice and Experience, 2(4):315-339, December 1990.
[16] A.S. Tanenbaum, M.F. Kaashoek, and H.E. Bal. Parallel programming using shared ob jects and broadcasting. IEEE Computer, 25(8):10-20, August 1992.
[17] A.S. Tanenbaum, R. van Renesse, H. van Staveren, G.J. Sharp, S.J. Mullender, J. Jansen, and G. van Rossum. Experiences with the Amoeba distributed operating system. Communications of the ACM, 33(12):46-63, December 1990.

















