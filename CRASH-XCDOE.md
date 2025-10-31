-------------------------------------
Translated Report (Full Report Below)
-------------------------------------
Process:             SWBBuildService [30863]
Path:                /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/MacOS/SWBBuildService
Identifier:          com.apple.dt.SWBBuildService
Version:             16.0 (24000.1.210)
Build Info:          XCBuild-24000001210000000~66 (17A400)
Code Type:           ARM-64 (Native)
Role:                Unspecified
Parent Process:      Xcode [25447]
Coalition:           com.apple.dt.Xcode [1593]
Responsible Process: Xcode [25447]
User ID:             501

Date/Time:           2025-10-31 06:06:30.4527 +0300
Launch Time:         2025-10-31 06:06:22.6941 +0300
Hardware Model:      Mac16,10
OS Version:          macOS 26.1 (25B5062e)
Release Type:        User

Crash Reporter Key:  3CA93170-003B-3D28-081B-3F97C14EE36F
Incident Identifier: C5750357-6202-4DA2-89BD-A870C12AD535

Time Awake Since Boot: 2300 seconds

System Integrity Protection: enabled

Triggered by Thread: 2, Dispatch Queue: com.apple.root.default-qos.cooperative

Exception Type:    EXC_BREAKPOINT (SIGTRAP)
Exception Codes:   0x0000000000000001, 0x000000010446604c

Termination Reason:  Namespace SIGNAL, Code 5, Trace/BPT trap: 5
Terminating Process: exc handler [30863]


Thread 0::  Dispatch queue: com.apple.main-thread
0   libsystem_kernel.dylib        	       0x18270ac34 mach_msg2_trap + 8
1   libsystem_kernel.dylib        	       0x18271d028 mach_msg2_internal + 76
2   libsystem_kernel.dylib        	       0x18271398c mach_msg_overwrite + 484
3   libsystem_kernel.dylib        	       0x18270afb4 mach_msg + 24
4   CoreFoundation                	       0x1827ecb90 __CFRunLoopServiceMachPort + 160
5   CoreFoundation                	       0x1827eb4e8 __CFRunLoopRun + 1188
6   CoreFoundation                	       0x1828a535c _CFRunLoopRunSpecificWithOptions + 532
7   CoreFoundation                	       0x18283ea30 CFRunLoopRun + 64
8   libswift_Concurrency.dylib    	       0x27bc8fee8 CFMainExecutor.run() + 48
9   libswift_Concurrency.dylib    	       0x27bc8fba0 protocol witness for RunLoopExecutor.run() in conformance DispatchMainExecutor + 48
10  libswift_Concurrency.dylib    	       0x27bc8ff94 swift_task_asyncMainDrainQueueImpl + 108
11  libswift_Concurrency.dylib    	       0x27bcafa34 swift_task_asyncMainDrainQueue + 92
12  SWBBuildService               	       0x10217ca54 main + 84
13  dyld                          	       0x182385d54 start + 7184

Thread 1:

Thread 2 Crashed::  Dispatch queue: com.apple.root.default-qos.cooperative
0   libSwiftDriver.dylib          	       0x10446604c 0x104300000 + 1466444
1   libSwiftDriver.dylib          	       0x104463804 0x104300000 + 1456132
2   libSwiftDriver.dylib          	       0x10438e080 0x104300000 + 581760
3   libSwiftDriver.dylib          	       0x10438d5e8 0x104300000 + 579048
4   libSwiftDriver.dylib          	       0x10442ded8 0x104300000 + 1236696
5   libSwiftDriver.dylib          	       0x10442d4b8 0x104300000 + 1234104
6   libSwiftDriver.dylib          	       0x10442b144 0x104300000 + 1225028
7   libSwiftDriver.dylib          	       0x1043118a4 0x104300000 + 71844
8   SWBCore                       	       0x103a4d19c LibSwiftDriver.run(dryRun:) + 64
9   SWBCore                       	       0x103a54658 specialized static LibSwiftDriver.createAndPlan(for:outputDelegate:compilerLocation:target:workingDirectory:tempDirPath:explicitModulesTempDirPath:commandLine:environment:eagerCompilationEnabled:casOptions:) + 3504
10  SWBCore                       	       0x103a48694 SwiftModuleDependencyGraph.planBuild(key:outputDelegate:compilerLocation:target:args:workingDirectory:tempDirPath:explicitModulesTempDirPath:environment:eagerCompilationEnabled:casOptions:) + 120
11  SWBTaskExecution              	       0x1036e97f8 SwiftDriverTaskAction.performTaskAction(_:dynamicExecutionDelegate:executionDelegate:clientDelegate:outputDelegate:) + 1676
12  SWBBuildSystem                	       0x10295b1ed InProcessCommand.execute(_:_:_:) + 1
13  SWBBuildSystem                	       0x10295ad89 closure #1 in InProcessCommand.execute(_:_:_:) + 1
14  SWBBuildSystem                	       0x102970611 <deduplicated_symbol> + 1
15  SWBUtil                       	       0x1022f28d1 closure #1 in closure #2 in runAsyncAndBlock<A, B>(_:) + 1
16  SWBUtil                       	       0x1022be001 <deduplicated_symbol> + 1
17  SWBUtil                       	       0x102386da9 static Result.catching(_:) + 1
18  SWBUtil                       	       0x1022f2659 closure #2 in runAsyncAndBlock<A, B>(_:) + 1
19  SWBUtil                       	       0x1022be001 <deduplicated_symbol> + 1
20  SWBUtil                       	       0x102336dad <deduplicated_symbol> + 1
21  SWBUtil                       	       0x1022c0b81 <deduplicated_symbol> + 1
22  libswift_Concurrency.dylib    	       0x27bcb06c1 completeTaskWithClosure(swift::AsyncContext*, swift::SwiftError*) + 1

Thread 3:

Thread 4:

Thread 5:

Thread 6:

Thread 7:

Thread 8:

Thread 9:

Thread 10:

Thread 11:

Thread 12:

Thread 13:: llb_buildsystem_build
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d3a5dc llbuild::core::BuildEngine::build(llbuild::core::KeyType const&) + 3368
4   llbuild                       	       0x102d51acc (anonymous namespace)::BuildSystemImpl::build(llbuild::buildsystem::BuildKey) + 200
5   llbuild                       	       0x102d51ca0 llbuild::buildsystem::BuildSystem::build(llvm::StringRef) + 248
6   llbuild                       	       0x102d450ec llbuild::buildsystem::BuildSystemFrontend::build(llvm::StringRef) + 56
7   llbuild                       	       0x102cd1a00 0x102cb8000 + 104960
8   SWBBuildSystem                	       0x10296e7ac partial apply for closure #7 in BuildOperation._build(cacheEntry:dbPath:traceFile:debuggingDataPath:buildEnvironment:) + 28
9   libswift_Concurrency.dylib    	       0x27bc778cc TaskLocal.withValue<A>(_:operation:file:line:) + 232
10  SWBUtil                       	       0x1023a7858 closure #1 in closure #1 in static Task<>.detachNewThread(name:_:) + 304
11  SWBUtil                       	       0x10239dc7c thunk for @escaping @callee_guaranteed () -> () + 28
12  Foundation                    	       0x184a6825c __NSThread__block_start__ + 76
13  libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
14  libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 14:: org.swift.llbuild Lane-0
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 15:: org.swift.llbuild Lane-1
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 16:: org.swift.llbuild Lane-2
0   libsystem_kernel.dylib        	       0x18270abb0 semaphore_wait_trap + 8
1   libdispatch.dylib             	       0x182592990 _dispatch_sema4_wait + 28
2   libdispatch.dylib             	       0x182592f40 _dispatch_semaphore_wait_slow + 132
3   SWBUtil                       	       0x10239bff0 closure #1 in SWBDispatchSemaphore.blocking_wait() + 24
4   SWBUtil                       	       0x1022f46cc partial apply for closure #1 in SWBDispatchSemaphore.blocking_wait() + 16
5   SWBUtil                       	       0x1022f4708 partial apply for specialized closure #1 in assertNoConcurrency<A>(_:) + 20
6   libswift_Concurrency.dylib    	       0x27bc6f0e4 withUnsafeCurrentTask<A>(body:) + 120
7   SWBUtil                       	       0x1022f2340 runAsyncAndBlock<A, B>(_:) + 768
8   SWBBuildSystem                	       0x10295ba8c protocol witness for ExternalCommand.execute(_:_:_:) in conformance InProcessCommand + 184
9   llbuild                       	       0x102ccda30 0x102cb8000 + 88624
10  llbuild                       	       0x102cbfce8 (anonymous namespace)::CAPIExternalCommand::executeExternalCommand(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>) + 332
11  llbuild                       	       0x102d49e1c llbuild::buildsystem::ExternalCommand::execute(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, std::__1::function<void (llbuild::buildsystem::BuildValue&&)>) + 792
12  llbuild                       	       0x102d60678 (anonymous namespace)::CommandTask::inputsAvailable(llbuild::core::TaskInterface)::'lambda'(llbuild::basic::QueueJobContext*)::operator()(llbuild::basic::QueueJobContext*) + 200
13  llbuild                       	       0x102d2ca30 (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 760
14  llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
15  libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
16  libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 17:: org.swift.llbuild Lane-3
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 18:: org.swift.llbuild Lane-4
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 19:: org.swift.llbuild Lane-5
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 20:: org.swift.llbuild Lane-6
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 21:: org.swift.llbuild Lane-7
0   libsystem_kernel.dylib        	       0x1827136c0 poll + 8
1   llbuild                       	       0x102d34060 llbuild::basic::spawnProcess(llbuild::basic::ProcessDelegate&, llbuild::basic::ProcessContext*, llbuild::basic::ProcessGroup&, llbuild::basic::ProcessHandle, llvm::ArrayRef<llvm::StringRef>, llbuild::basic::POSIXEnvironment, llbuild::basic::ProcessAttributes, std::__1::function<void (std::__1::function<void ()>&&)>&&, std::__1::function<void (llbuild::basic::ProcessResult)>&&) + 2900
2   llbuild                       	       0x102d2d2c4 (anonymous namespace)::LaneBasedExecutionQueue::executeProcess(llbuild::basic::QueueJobContext*, llvm::ArrayRef<llvm::StringRef>, llvm::ArrayRef<std::__1::pair<llvm::StringRef, llvm::StringRef>>, llbuild::basic::ProcessAttributes, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>, llbuild::basic::ProcessDelegate*) + 996
3   llbuild                       	       0x102d39690 llbuild::core::TaskInterface::spawn(llbuild::basic::QueueJobContext*, llvm::ArrayRef<llvm::StringRef>, llvm::ArrayRef<std::__1::pair<llvm::StringRef, llvm::StringRef>>, llbuild::basic::ProcessAttributes, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>, llbuild::basic::ProcessDelegate*) + 164
4   llbuild                       	       0x102d47740 llbuild::buildsystem::ShellCommand::executeExternalCommand(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>) + 800
5   llbuild                       	       0x102d49e1c llbuild::buildsystem::ExternalCommand::execute(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, std::__1::function<void (llbuild::buildsystem::BuildValue&&)>) + 792
6   llbuild                       	       0x102d60678 (anonymous namespace)::CommandTask::inputsAvailable(llbuild::core::TaskInterface)::'lambda'(llbuild::basic::QueueJobContext*)::operator()(llbuild::basic::QueueJobContext*) + 200
7   llbuild                       	       0x102d2ca30 (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 760
8   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
9   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
10  libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 22:: org.swift.llbuild Lane-8
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8

Thread 23:: org.swift.llbuild Lane-9
0   libsystem_kernel.dylib        	       0x18270e4f8 __psynch_cvwait + 8
1   libsystem_pthread.dylib       	       0x18274e0dc _pthread_cond_wait + 984
2   libc++.1.dylib                	       0x18267e74c std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&) + 32
3   llbuild                       	       0x102d2c85c (anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int) + 292
4   llbuild                       	       0x102d2eadc void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*) + 76
5   libsystem_pthread.dylib       	       0x18274dc08 _pthread_start + 136
6   libsystem_pthread.dylib       	       0x182748ba8 thread_start + 8


Thread 2 crashed with ARM Thread State (64-bit):
    x0: 0x0000000000000000   x1: 0x0000000000000000   x2: 0x0000000000000030   x3: 0x000000016de20a34
    x4: 0x0000000000000030   x5: 0x000000016de20900   x6: 0x0000000000000000   x7: 0xfffff0003ffff800
    x8: 0x2d05fd8534b1005e   x9: 0x2d05fd8534b1005e  x10: 0x00000000000000c7  x11: 0x0000000c5dd436ea
   x12: 0x0000000000000000  x13: 0x00000001829f3260  x14: 0x000000000000fffd  x15: 0x00000001ef055bb8
   x16: 0x00000001827db6ec  x17: 0x00000001f05aa280  x18: 0x0000000000000000  x19: 0x0000000000000001
   x20: 0x0000000c59076400  x21: 0x0000000000000000  x22: 0x0000000c5dd436b0  x23: 0x000000000000006a
   x24: 0x000000016de20eb0  x25: 0x0000000c4c1e70c0  x26: 0xf000000000000087  x27: 0x0000000c63a940a0
   x28: 0x4000000c50c04300   fp: 0x000000016de20f50   lr: 0x0000000104465d24
    sp: 0x000000016de20eb0   pc: 0x000000010446604c cpsr: 0x60000000
   far: 0x0000000000000000  esr: 0xf2000001 (Breakpoint) brk 1

Binary Images:
       0x10217c000 -        0x10217ffff com.apple.dt.SWBBuildService (16.0) <0075e263-f7fa-39d3-afdc-b23c40f86418> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/MacOS/SWBBuildService
       0x10269c000 -        0x10270ffff com.apple.dt.SWBBuildService.Framework (16.0) <a947d678-e527-3e00-868e-cea271941cb9> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBBuildService.framework/Versions/A/SWBBuildService
       0x102280000 -        0x102293fff com.apple.dt.SWBCAS (16.0) <e9392a37-b77e-3282-9536-22f812b2dce8> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBCAS.framework/Versions/A/SWBCAS
       0x103a04000 -        0x103df7fff com.apple.dt.SWBCore (16.0) <8e72be42-defb-3b2f-a6b0-00aad8cb5d74> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBCore.framework/Versions/A/SWBCore
       0x1022b4000 -        0x1023ebfff com.apple.dt.SWBUtil (16.0) <b6d7b85d-c7dc-37e4-a53d-f51c44b4afb3> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBUtil.framework/Versions/A/SWBUtil
       0x102948000 -        0x102987fff com.apple.dt.SWBBuildSystem (16.0) <8503b13d-8eae-3996-94a1-ab1d9522ce1f> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBBuildSystem.framework/Versions/A/SWBBuildSystem
       0x102588000 -        0x1025bbfff com.apple.dt.SWBMacro (16.0) <e0ffb1c9-251e-35c4-9f6f-9647eecba93e> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBMacro.framework/Versions/A/SWBMacro
       0x10303c000 -        0x10311ffff com.apple.dt.SWBProtocol (16.0) <a62281cc-93d5-3a4b-a5c4-8f49a61f5a87> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBProtocol.framework/Versions/A/SWBProtocol
       0x1027f0000 -        0x1027fbfff com.apple.dt.SWBServiceCore (16.0) <f00dabd3-1a3a-3311-a3c7-9aad34a2969b> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBServiceCore.framework/Versions/A/SWBServiceCore
       0x10338c000 -        0x103507fff com.apple.dt.SWBTaskConstruction (16.0) <8177d38c-7c50-3e2a-af0b-ecabe763398c> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBTaskConstruction.framework/Versions/A/SWBTaskConstruction
       0x10363c000 -        0x10375ffff com.apple.dt.SWBTaskExecution (16.0) <c423ec04-26a8-37d4-9a5f-7bd9981f581f> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBTaskExecution.framework/Versions/A/SWBTaskExecution
       0x102244000 -        0x10224bfff com.apple.dt.SWBCSupport (16.0) <ef9b58e7-cb44-392d-9546-99d5be6883b3> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBCSupport.framework/Versions/A/SWBCSupport
       0x102258000 -        0x10225bfff com.apple.dt.SWBLibc (16.0) <96555d63-92cc-3f38-b67b-ad9421dba902> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBLibc.framework/Versions/A/SWBLibc
       0x102234000 -        0x102237fff com.apple.dt.SWBCLibc (16.0) <127ead11-0ca5-3432-b25b-5a8f09ba10e0> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBCLibc.framework/Versions/A/SWBCLibc
       0x104300000 -        0x10454ffff libSwiftDriver.dylib (*) <0be8cb94-7bab-3f90-899e-0e3e53c3e4be> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libSwiftDriver.dylib
       0x10221c000 -        0x10221ffff com.apple.dt.SWBLLBuild (16.0) <d4808d10-7f30-3f88-96e4-98569593c679> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBLLBuild.framework/Versions/A/SWBLLBuild
       0x102818000 -        0x1028e3fff libSwiftToolsSupport.dylib (*) <be3e8444-324b-3e8c-9d56-0ce565a558df> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libSwiftToolsSupport.dylib
       0x102cb8000 -        0x102d77fff com.apple.dt.llbuild (1.0) <84a22704-fd19-3d76-b7fb-e0282dbc2bf0> /Applications/Xcode.app/Contents/SharedFrameworks/llbuild.framework/Versions/A/llbuild
       0x102b60000 -        0x102b63fff com.apple.dt.SWBAndroidPlatformPlugin (16.0) <19eb5c35-d7fd-311b-ab59-1fc2db4044e7> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBAndroidPlatformPlugin.bundle/Contents/MacOS/SWBAndroidPlatformPlugin
       0x102bf8000 -        0x102c0ffff com.apple.dt.SWBAndroidPlatform (16.0) <9a34eb92-bc15-3b46-8593-067eec97d919> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBAndroidPlatformPlugin.bundle/Contents/Frameworks/SWBAndroidPlatform.framework/Versions/A/SWBAndroidPlatform
       0x102b70000 -        0x102b73fff com.apple.dt.SWBApplePlatformPlugin (16.0) <7a14f86d-ab3e-3da1-a363-c1ee8be14ec2> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBApplePlatformPlugin.bundle/Contents/MacOS/SWBApplePlatformPlugin
       0x102e18000 -        0x102e7bfff com.apple.dt.SWBApplePlatform (16.0) <8760cd0c-0526-31ed-901a-317bbb0c2f07> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBApplePlatformPlugin.bundle/Contents/Frameworks/SWBApplePlatform.framework/Versions/A/SWBApplePlatform
       0x102b80000 -        0x102b83fff com.apple.dt.SWBGenericUnixPlatformPlugin (16.0) <93512467-c2ed-3d10-82e1-e67327499a79> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBGenericUnixPlatformPlugin.bundle/Contents/MacOS/SWBGenericUnixPlatformPlugin
       0x102c3c000 -        0x102c47fff com.apple.dt.SWBGenericUnixPlatform (16.0) <d42f34a1-76be-3cd0-a908-21cdfbe0b459> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBGenericUnixPlatformPlugin.bundle/Contents/Frameworks/SWBGenericUnixPlatform.framework/Versions/A/SWBGenericUnixPlatform
       0x102b90000 -        0x102b93fff com.apple.dt.SWBQNXPlatformPlugin (16.0) <49c1fcd3-2222-3036-be4f-35e06518c6c7> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBQNXPlatformPlugin.bundle/Contents/MacOS/SWBQNXPlatformPlugin
       0x102c64000 -        0x102c6ffff com.apple.dt.SWBQNXPlatform (16.0) <12d9237c-df5f-36e0-b4f4-694aa3bf508e> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBQNXPlatformPlugin.bundle/Contents/Frameworks/SWBQNXPlatform.framework/Versions/A/SWBQNXPlatform
       0x102ba0000 -        0x102ba3fff com.apple.dt.SWBUniversalPlatformPlugin (16.0) <4118fb3b-59f0-367b-a691-a0bb53bf752f> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBUniversalPlatformPlugin.bundle/Contents/MacOS/SWBUniversalPlatformPlugin
       0x102bb0000 -        0x102bbbfff com.apple.dt.SWBUniversalPlatform (16.0) <ac9e0ad7-1ad3-3e08-9d7d-330e648a11c6> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBUniversalPlatformPlugin.bundle/Contents/Frameworks/SWBUniversalPlatform.framework/Versions/A/SWBUniversalPlatform
       0x102be4000 -        0x102be7fff com.apple.dt.SWBWebAssemblyPlatformPlugin (16.0) <6df45e7f-ac14-316a-bf27-5ec9683e342a> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBWebAssemblyPlatformPlugin.bundle/Contents/MacOS/SWBWebAssemblyPlatformPlugin
       0x102b44000 -        0x102b4bfff com.apple.dt.SWBWebAssemblyPlatform (16.0) <6407ea7f-92c0-36e2-a943-fd41722b6e9a> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBWebAssemblyPlatformPlugin.bundle/Contents/Frameworks/SWBWebAssemblyPlatform.framework/Versions/A/SWBWebAssemblyPlatform
       0x102ca8000 -        0x102cabfff com.apple.dt.SWBWindowsPlatformPlugin (16.0) <b53c01c5-9203-389f-b5cb-e73366de1cef> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBWindowsPlatformPlugin.bundle/Contents/MacOS/SWBWindowsPlatformPlugin
       0x102fa4000 -        0x102faffff com.apple.dt.SWBWindowsPlatform (16.0) <35e40f47-de15-3e45-82e6-30ff3266ff7a> /Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns/SWBWindowsPlatformPlugin.bundle/Contents/Frameworks/SWBWindowsPlatform.framework/Versions/A/SWBWindowsPlatform
       0x10c26c000 -        0x10c8c3fff libToolchainCASPlugin.dylib (*) <5a42c6a3-f972-32e7-a651-058d926a965b> /Applications/Xcode.app/Contents/Developer/usr/lib/libToolchainCASPlugin.dylib
       0x11d380000 -        0x122823fff libclang.dylib (*) <d2c6e450-7eb0-3251-988c-8eef79c6b1b3> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libclang.dylib
       0x10d1e0000 -        0x114b8bfff lib_InternalSwiftScan.dylib (*) <efb5a9d4-8ff8-32cb-93d9-fa64de9513ea> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_InternalSwiftScan.dylib
       0x11725c000 -        0x11726bfff lib_CompilerSwiftIDEUtils.dylib (*) <45db6512-1468-3976-9459-07d7bafebb8e> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftIDEUtils.dylib
       0x117460000 -        0x11749ffff lib_CompilerSwiftCompilerPluginMessageHandling.dylib (*) <2800b377-f531-3978-9ecb-209ca3331878> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftCompilerPluginMessageHandling.dylib
       0x11719c000 -        0x1171bffff lib_CompilerSwiftSyntaxMacroExpansion.dylib (*) <b20d2d64-7837-3b43-a54d-8453523c93f7> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftSyntaxMacroExpansion.dylib
       0x117308000 -        0x117313fff lib_CompilerSwiftSyntaxMacros.dylib (*) <c4039a42-47aa-3edc-9c74-5dc225052c6e> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftSyntaxMacros.dylib
       0x1173f8000 -        0x117417fff lib_CompilerSwiftLexicalLookup.dylib (*) <0f31ca8a-2250-38c6-8c5d-29eaa669f633> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftLexicalLookup.dylib
       0x117330000 -        0x11734ffff lib_CompilerSwiftIfConfig.dylib (*) <38c3941a-bc9c-3ad4-9067-91110b5befa2> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftIfConfig.dylib
       0x11764c000 -        0x117663fff lib_CompilerSwiftOperators.dylib (*) <93806371-9d52-36f3-b52b-58a10136e16f> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftOperators.dylib
       0x117904000 -        0x117933fff lib_CompilerSwiftSyntaxBuilder.dylib (*) <56187966-1c32-34df-b6af-7c8a4f68ab44> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftSyntaxBuilder.dylib
       0x1176d8000 -        0x11772bfff lib_CompilerSwiftParserDiagnostics.dylib (*) <dc767e0f-3139-3e4e-9428-5750d2f31677> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftParserDiagnostics.dylib
       0x117eb8000 -        0x117fa7fff lib_CompilerSwiftParser.dylib (*) <9c3ebeda-88e0-3958-bc3f-974a41232a3f> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftParser.dylib
       0x117838000 -        0x117847fff lib_CompilerSwiftBasicFormat.dylib (*) <539ed3fb-05fb-37cd-b6a7-ef42440be838> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftBasicFormat.dylib
       0x1172bc000 -        0x1172cffff lib_CompilerSwiftDiagnostics.dylib (*) <304ffbb0-f705-31d2-beb4-ff78c14ee394> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftDiagnostics.dylib
       0x119860000 -        0x119b2ffff lib_CompilerSwiftSyntax.dylib (*) <b9313ebc-5057-3a72-9eab-d27484b3470a> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/compiler/lib_CompilerSwiftSyntax.dylib
       0x11b720000 -        0x11b73ffff com.apple.security.csparser (3.0) <7d2e7f9c-0502-33e9-85d0-fb94391908c5> /System/Library/Frameworks/Security.framework/Versions/A/PlugIns/csparser.bundle/Contents/MacOS/csparser
       0x18270a000 -        0x18274649f libsystem_kernel.dylib (*) <fef6120d-486d-336f-bdb7-6726a8470164> /usr/lib/system/libsystem_kernel.dylib
       0x18278d000 -        0x182cd39ff com.apple.CoreFoundation (6.9) <2d53b2a7-982b-35d0-8a48-d9abd271e3f6> /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation
       0x27bc43000 -        0x27bccca8f libswift_Concurrency.dylib (*) <75bbae83-0f68-3468-98c8-341e43ee29c1> /usr/lib/swift/libswift_Concurrency.dylib
       0x18237d000 -        0x18241bf67 dyld (*) <332c49eb-6f8b-32d6-b9f4-88f99cc8f003> /usr/lib/dyld
               0x0 - 0xffffffffffffffff ??? (*) <00000000-0000-0000-0000-000000000000> ???
       0x182747000 -        0x182753abb libsystem_pthread.dylib (*) <f37b8a66-9bab-32a0-b222-76d650a69d19> /usr/lib/system/libsystem_pthread.dylib
       0x18265c000 -        0x1826eee53 libc++.1.dylib (*) <2b3315df-0e29-33bf-9c56-16de7636ff10> /usr/lib/libc++.1.dylib
       0x183fd7000 -        0x184f64c5f com.apple.Foundation (6.9) <20052a64-6414-35c2-a85b-6ded628cf1b2> /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation
       0x18258f000 -        0x1825d5e9f libdispatch.dylib (*) <57fb5b7e-54d3-3c19-aa16-2c6470fed988> /usr/lib/system/libdispatch.dylib

External Modification Summary:
  Calls made by other processes targeting this process:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0
  Calls made by this process:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0
  Calls made by all processes on this machine:
    task_for_pid: 0
    thread_create: 0
    thread_set_state: 0

VM Region Summary:
ReadOnly portion of Libraries: Total=1.2G resident=0K(0%) swapped_out_or_unallocated=1.2G(100%)
Writable regions: Total=967.3M written=961K(0%) resident=961K(0%) swapped_out=0K(0%) unallocated=966.4M(100%)

                                VIRTUAL   REGION
REGION TYPE                        SIZE    COUNT (non-coalesced)
===========                     =======  =======
Activity Tracing                   256K        1
Kernel Alloc Once                   32K        1
MALLOC                           882.9M      170
MALLOC guard page                 3792K        4
SQLite page cache                 60.2M      482
STACK GUARD                       56.4M       24
Stack                             20.2M       24
VM_ALLOCATE                        544K        3
__AUTH                            1310K      148
__AUTH_CONST                      17.1M      341
__CTF                               824        1
__DATA                            9548K      351
__DATA_CONST                      25.5M      388
__DATA_DIRTY                      1332K      286
__FONT_DATA                        2352        1
__LINKEDIT                       694.9M       50
__OBJC_RO                         78.2M        1
__OBJC_RW                         2567K        1
__TEXT                           512.8M      398
__TPRO_CONST                       128K        2
dyld private memory                160K        4
mapped file                       25.1G       75
page table in kernel               961K        1
shared memory                     1200K        9
===========                     =======  =======
TOTAL                             27.4G     2766


-----------
Full Report
-----------

{"app_name":"SWBBuildService","timestamp":"2025-10-31 06:06:30.00 +0300","app_version":"16.0","slice_uuid":"0075e263-f7fa-39d3-afdc-b23c40f86418","build_version":"24000.1.210","platform":1,"bundleID":"com.apple.dt.SWBBuildService","share_with_app_devs":0,"is_first_party":1,"bug_type":"309","os_version":"macOS 26.1 (25B5062e)","roots_installed":0,"name":"SWBBuildService","incident_id":"C5750357-6202-4DA2-89BD-A870C12AD535"}
{
  "uptime" : 2300,
  "procRole" : "Unspecified",
  "version" : 2,
  "userID" : 501,
  "deployVersion" : 210,
  "modelCode" : "Mac16,10",
  "coalitionID" : 1593,
  "osVersion" : {
    "train" : "macOS 26.1",
    "build" : "25B5062e",
    "releaseType" : "User"
  },
  "captureTime" : "2025-10-31 06:06:30.4527 +0300",
  "codeSigningMonitor" : 2,
  "incident" : "C5750357-6202-4DA2-89BD-A870C12AD535",
  "pid" : 30863,
  "translated" : false,
  "cpuType" : "ARM-64",
  "roots_installed" : 0,
  "bug_type" : "309",
  "procLaunch" : "2025-10-31 06:06:22.6941 +0300",
  "procStartAbsTime" : 56973525385,
  "procExitAbsTime" : 57159723269,
  "procName" : "SWBBuildService",
  "procPath" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/MacOS\/SWBBuildService",
  "bundleInfo" : {"CFBundleShortVersionString":"16.0","CFBundleVersion":"24000.1.210","CFBundleIdentifier":"com.apple.dt.SWBBuildService"},
  "buildInfo" : {"ProjectName":"XCBuild","SourceVersion":"24000001210000000","ProductBuildVersion":"17A400","BuildVersion":"66"},
  "parentProc" : "Xcode",
  "parentPid" : 25447,
  "coalitionName" : "com.apple.dt.Xcode",
  "crashReporterKey" : "3CA93170-003B-3D28-081B-3F97C14EE36F",
  "developerMode" : 1,
  "responsiblePid" : 25447,
  "responsibleProc" : "Xcode",
  "codeSigningID" : "com.apple.dt.SWBBuildService",
  "codeSigningTeamID" : "",
  "codeSigningFlags" : 570442241,
  "codeSigningValidationCategory" : 1,
  "codeSigningTrustLevel" : 4294967295,
  "codeSigningAuxiliaryInfo" : 0,
  "instructionByteStream" : {"beforePC":"+2tBqfwHRvjAA1\/W4AMZqopWApSgA1n44P\/\/FyAAINQgACDUIAAg1A==","atPC":"IAAg1CAAINSI8kD5HwEA8eAHnxrAA1\/WiEpB+egAALSITkH5qAAAtA=="},
  "bootSessionUUID" : "6D8984C3-074D-4342-A4A5-079961ABCE2D",
  "sip" : "enabled",
  "exception" : {"codes":"0x0000000000000001, 0x000000010446604c","rawCodes":[1,4366688332],"type":"EXC_BREAKPOINT","signal":"SIGTRAP"},
  "termination" : {"flags":0,"code":5,"namespace":"SIGNAL","indicator":"Trace\/BPT trap: 5","byProc":"exc handler","byPid":30863},
  "os_fault" : {"process":"SWBBuildService"},
  "extMods" : {"caller":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"system":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"targeted":{"thread_create":0,"thread_set_state":0,"task_for_pid":0},"warnings":0},
  "faultingThread" : 2,
  "threads" : [{"id":133424,"threadState":{"x":[{"value":268451845},{"value":21592279046},{"value":8589934592,"objc-selector":"arWrapper"},{"value":11008001179648},{"value":1841831988},{"value":11008001179648},{"value":2},{"value":4294967295},{"value":0},{"value":17179869184},{"value":0},{"value":2},{"value":0},{"value":0},{"value":2563},{"value":0},{"value":18446744073709551569},{"value":12},{"value":0},{"value":4294967295},{"value":2},{"value":11008001179648},{"value":1841831988},{"value":11008001179648},{"value":6136798648},{"value":8589934592,"objc-selector":"arWrapper"},{"value":21592279046},{"value":18446744073709550527},{"value":4412409862}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483464232},"cpsr":{"value":0},"fp":{"value":6136798496},"sp":{"value":6136798416},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483389492},"far":{"value":0}},"queue":"com.apple.main-thread","frames":[{"imageOffset":3124,"symbol":"mach_msg2_trap","symbolLocation":8,"imageIndex":49},{"imageOffset":77864,"symbol":"mach_msg2_internal","symbolLocation":76,"imageIndex":49},{"imageOffset":39308,"symbol":"mach_msg_overwrite","symbolLocation":484,"imageIndex":49},{"imageOffset":4020,"symbol":"mach_msg","symbolLocation":24,"imageIndex":49},{"imageOffset":392080,"symbol":"__CFRunLoopServiceMachPort","symbolLocation":160,"imageIndex":50},{"imageOffset":386280,"symbol":"__CFRunLoopRun","symbolLocation":1188,"imageIndex":50},{"imageOffset":1147740,"symbol":"_CFRunLoopRunSpecificWithOptions","symbolLocation":532,"imageIndex":50},{"imageOffset":727600,"symbol":"CFRunLoopRun","symbolLocation":64,"imageIndex":50},{"imageOffset":315112,"symbol":"CFMainExecutor.run()","symbolLocation":48,"imageIndex":51},{"imageOffset":314272,"symbol":"protocol witness for RunLoopExecutor.run() in conformance DispatchMainExecutor","symbolLocation":48,"imageIndex":51},{"imageOffset":315284,"symbol":"swift_task_asyncMainDrainQueueImpl","symbolLocation":108,"imageIndex":51},{"imageOffset":444980,"symbol":"swift_task_asyncMainDrainQueue","symbolLocation":92,"imageIndex":51},{"imageOffset":2644,"symbol":"main","symbolLocation":84,"imageIndex":0},{"imageOffset":36180,"symbol":"start","symbolLocation":7184,"imageIndex":52}]},{"id":133426,"frames":[],"threadState":{"x":[{"value":6137360384},{"value":7427},{"value":6136823808},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6137360384},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"triggered":true,"id":133428,"threadState":{"x":[{"value":0},{"value":0},{"value":48},{"value":6138497588},{"value":48},{"value":6138497280},{"value":0},{"value":18446726482597246976},{"value":3244277855146803294},{"value":3244277855146803294},{"value":199},{"value":53113796330},{"value":0},{"value":6486438496,"symbolLocation":0,"symbol":"offsetsFromUTF8"},{"value":65533},{"value":8305073080,"symbolLocation":0,"symbol":"OBJC_CLASS_$_NSPlaceholderString"},{"value":6484244204,"symbolLocation":0,"symbol":"CFStringCreateWithBytesNoCopy"},{"value":8327438976},{"value":0},{"value":1},{"value":53033264128},{"value":0},{"value":53113796272},{"value":106},{"value":6138498736},{"value":52816670912},{"value":17293822569102704775},{"value":53211644064},{"value":4611686071321772800}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4366687524},"cpsr":{"value":1610612736},"fp":{"value":6138498896},"sp":{"value":6138498736},"esr":{"value":4060086273,"description":"(Breakpoint) brk 1"},"pc":{"value":4366688332,"matchesCrashFrame":1},"far":{"value":0}},"queue":"com.apple.root.default-qos.cooperative","frames":[{"imageOffset":1466444,"imageIndex":14},{"imageOffset":1456132,"imageIndex":14},{"imageOffset":581760,"imageIndex":14},{"imageOffset":579048,"imageIndex":14},{"imageOffset":1236696,"imageIndex":14},{"imageOffset":1234104,"imageIndex":14},{"imageOffset":1225028,"imageIndex":14},{"imageOffset":71844,"imageIndex":14},{"imageOffset":299420,"symbol":"LibSwiftDriver.run(dryRun:)","symbolLocation":64,"imageIndex":3},{"imageOffset":329304,"symbol":"specialized static LibSwiftDriver.createAndPlan(for:outputDelegate:compilerLocation:target:workingDirectory:tempDirPath:explicitModulesTempDirPath:commandLine:environment:eagerCompilationEnabled:casOptions:)","symbolLocation":3504,"imageIndex":3},{"imageOffset":280212,"symbol":"SwiftModuleDependencyGraph.planBuild(key:outputDelegate:compilerLocation:target:args:workingDirectory:tempDirPath:explicitModulesTempDirPath:environment:eagerCompilationEnabled:casOptions:)","symbolLocation":120,"imageIndex":3},{"imageOffset":710648,"symbol":"SwiftDriverTaskAction.performTaskAction(_:dynamicExecutionDelegate:executionDelegate:clientDelegate:outputDelegate:)","symbolLocation":1676,"imageIndex":10},{"imageOffset":78317,"symbol":"InProcessCommand.execute(_:_:_:)","symbolLocation":1,"imageIndex":5},{"imageOffset":77193,"symbol":"closure #1 in InProcessCommand.execute(_:_:_:)","symbolLocation":1,"imageIndex":5},{"imageOffset":165393,"symbol":"<deduplicated_symbol>","symbolLocation":1,"imageIndex":5},{"imageOffset":256209,"symbol":"closure #1 in closure #2 in runAsyncAndBlock<A, B>(_:)","symbolLocation":1,"imageIndex":4},{"imageOffset":40961,"symbol":"<deduplicated_symbol>","symbolLocation":1,"imageIndex":4},{"imageOffset":863657,"symbol":"static Result.catching(_:)","symbolLocation":1,"imageIndex":4},{"imageOffset":255577,"symbol":"closure #2 in runAsyncAndBlock<A, B>(_:)","symbolLocation":1,"imageIndex":4},{"imageOffset":40961,"symbol":"<deduplicated_symbol>","symbolLocation":1,"imageIndex":4},{"imageOffset":535981,"symbol":"<deduplicated_symbol>","symbolLocation":1,"imageIndex":4},{"imageOffset":52097,"symbol":"<deduplicated_symbol>","symbolLocation":1,"imageIndex":4},{"imageOffset":448193,"symbol":"completeTaskWithClosure(swift::AsyncContext*, swift::SwiftError*)","symbolLocation":1,"imageIndex":51}]},{"id":133429,"frames":[],"threadState":{"x":[{"value":6139080704},{"value":16139},{"value":6138544128},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6139080704},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133430,"frames":[],"threadState":{"x":[{"value":6139654144},{"value":11011},{"value":6139117568},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6139654144},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133431,"frames":[],"threadState":{"x":[{"value":6140227584},{"value":15875},{"value":6139691008},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6140227584},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133432,"frames":[],"threadState":{"x":[{"value":6140801024},{"value":11267},{"value":6140264448},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6140801024},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133433,"frames":[],"threadState":{"x":[{"value":6141374464},{"value":15619},{"value":6140837888},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6141374464},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133434,"frames":[],"threadState":{"x":[{"value":6141947904},{"value":15363},{"value":6141411328},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6141947904},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133435,"frames":[],"threadState":{"x":[{"value":6142521344},{"value":15107},{"value":6141984768},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6142521344},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133441,"frames":[],"threadState":{"x":[{"value":6143094784},{"value":14339},{"value":6142558208},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6143094784},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133442,"frames":[],"threadState":{"x":[{"value":6143668224},{"value":14083},{"value":6143131648},{"value":0},{"value":409604},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6143668224},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133443,"frames":[],"threadState":{"x":[{"value":6144241664},{"value":0},{"value":6143705088},{"value":0},{"value":278532},{"value":18446744073709551615},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0},{"value":0}],"flavor":"ARM_THREAD_STATE64","lr":{"value":0},"cpsr":{"value":0},"fp":{"value":0},"sp":{"value":6144241664},"esr":{"value":0},"pc":{"value":6483643284},"far":{"value":0}}},{"id":133453,"name":"llb_buildsystem_build","threadState":{"x":[{"value":260},{"value":0},{"value":248576},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6144813544},{"value":0},{"value":1280},{"value":5497558140162},{"value":5497558140162},{"value":1280},{"value":0},{"value":5497558140160},{"value":305},{"value":8328123592},{"value":0},{"value":53029839568},{"value":53029839632},{"value":6144815328},{"value":0},{"value":0},{"value":248576},{"value":248577},{"value":248832},{"value":6144813904},{"value":53029838976}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6144813664},"sp":{"value":6144813520},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":533980,"symbol":"llbuild::core::BuildEngine::build(llbuild::core::KeyType const&)","symbolLocation":3368,"imageIndex":17},{"imageOffset":629452,"symbol":"(anonymous namespace)::BuildSystemImpl::build(llbuild::buildsystem::BuildKey)","symbolLocation":200,"imageIndex":17},{"imageOffset":629920,"symbol":"llbuild::buildsystem::BuildSystem::build(llvm::StringRef)","symbolLocation":248,"imageIndex":17},{"imageOffset":577772,"symbol":"llbuild::buildsystem::BuildSystemFrontend::build(llvm::StringRef)","symbolLocation":56,"imageIndex":17},{"imageOffset":104960,"imageIndex":17},{"imageOffset":157612,"symbol":"partial apply for closure #7 in BuildOperation._build(cacheEntry:dbPath:traceFile:debuggingDataPath:buildEnvironment:)","symbolLocation":28,"imageIndex":5},{"imageOffset":215244,"symbol":"TaskLocal.withValue<A>(_:operation:file:line:)","symbolLocation":232,"imageIndex":51},{"imageOffset":997464,"symbol":"closure #1 in closure #1 in static Task<>.detachNewThread(name:_:)","symbolLocation":304,"imageIndex":4},{"imageOffset":957564,"symbol":"thunk for @escaping @callee_guaranteed () -> ()","symbolLocation":28,"imageIndex":4},{"imageOffset":11080284,"symbol":"__NSThread__block_start__","symbolLocation":76,"imageIndex":56},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133454,"name":"org.swift.llbuild Lane-0","threadState":{"x":[{"value":4},{"value":0},{"value":169728},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6145387960},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6145388768},{"value":0},{"value":0},{"value":169728},{"value":169728},{"value":171264},{"value":6145388272},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6145388080},"sp":{"value":6145387936},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133455,"name":"org.swift.llbuild Lane-1","threadState":{"x":[{"value":4},{"value":0},{"value":169728},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6145961400},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6145962208},{"value":0},{"value":0},{"value":169728},{"value":169728},{"value":170752},{"value":6145961712},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6145961520},"sp":{"value":6145961376},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133456,"name":"org.swift.llbuild Lane-2","threadState":{"x":[{"value":14},{"value":0},{"value":8352608904,"symbolLocation":8,"symbol":"type metadata for ()"},{"value":201328895},{"value":8304893296,"symbolLocation":48,"symbol":"_OS_dispatch_queue_cooperative_vtable"},{"value":0},{"value":1},{"value":18446726482597246976},{"value":0},{"value":18446744073709551615},{"value":8589934595,"objc-selector":"rapper"},{"value":17179869187},{"value":1985216},{"value":9476939122360033137},{"value":4371311960},{"value":53036023808},{"value":18446744073709551580},{"value":8328127936},{"value":0},{"value":53030308256},{"value":53030308192},{"value":18446744073709551615},{"value":0},{"value":8352608896,"symbolLocation":0,"symbol":"type metadata for ()"},{"value":4338521008,"symbolLocation":16,"symbol":"full type metadata for llb_buildsystem_command_result_t"},{"value":52879757184},{"value":6146533424},{"value":0},{"value":6146533456}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6481848720},"cpsr":{"value":1610612736},"fp":{"value":6146533168},"sp":{"value":6146533152},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483389360},"far":{"value":0}},"frames":[{"imageOffset":2992,"symbol":"semaphore_wait_trap","symbolLocation":8,"imageIndex":49},{"imageOffset":14736,"symbol":"_dispatch_sema4_wait","symbolLocation":28,"imageIndex":57},{"imageOffset":16192,"symbol":"_dispatch_semaphore_wait_slow","symbolLocation":132,"imageIndex":57},{"imageOffset":950256,"symbol":"closure #1 in SWBDispatchSemaphore.blocking_wait()","symbolLocation":24,"imageIndex":4},{"imageOffset":263884,"symbol":"partial apply for closure #1 in SWBDispatchSemaphore.blocking_wait()","symbolLocation":16,"imageIndex":4},{"imageOffset":263944,"symbol":"partial apply for specialized closure #1 in assertNoConcurrency<A>(_:)","symbolLocation":20,"imageIndex":4},{"imageOffset":180452,"symbol":"withUnsafeCurrentTask<A>(body:)","symbolLocation":120,"imageIndex":51},{"imageOffset":254784,"symbol":"runAsyncAndBlock<A, B>(_:)","symbolLocation":768,"imageIndex":4},{"imageOffset":80524,"symbol":"protocol witness for ExternalCommand.execute(_:_:_:) in conformance InProcessCommand","symbolLocation":184,"imageIndex":5},{"imageOffset":88624,"imageIndex":17},{"imageOffset":31976,"symbol":"(anonymous namespace)::CAPIExternalCommand::executeExternalCommand(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>)","symbolLocation":332,"imageIndex":17},{"imageOffset":597532,"symbol":"llbuild::buildsystem::ExternalCommand::execute(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, std::__1::function<void (llbuild::buildsystem::BuildValue&&)>)","symbolLocation":792,"imageIndex":17},{"imageOffset":689784,"symbol":"(anonymous namespace)::CommandTask::inputsAvailable(llbuild::core::TaskInterface)::'lambda'(llbuild::basic::QueueJobContext*)::operator()(llbuild::basic::QueueJobContext*)","symbolLocation":200,"imageIndex":17},{"imageOffset":477744,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":760,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133457,"name":"org.swift.llbuild Lane-3","threadState":{"x":[{"value":4},{"value":0},{"value":169728},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6147108280},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6147109088},{"value":0},{"value":0},{"value":169728},{"value":169728},{"value":171008},{"value":6147108592},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6147108400},"sp":{"value":6147108256},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133458,"name":"org.swift.llbuild Lane-4","threadState":{"x":[{"value":4},{"value":0},{"value":169984},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6147681720},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6147682528},{"value":0},{"value":0},{"value":169984},{"value":169984},{"value":171776},{"value":6147682032},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6147681840},"sp":{"value":6147681696},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133459,"name":"org.swift.llbuild Lane-5","threadState":{"x":[{"value":4},{"value":0},{"value":170240},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6148255160},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6148255968},{"value":0},{"value":0},{"value":170240},{"value":170240},{"value":172544},{"value":6148255472},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6148255280},"sp":{"value":6148255136},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133460,"name":"org.swift.llbuild Lane-6","threadState":{"x":[{"value":4},{"value":0},{"value":169984},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6148828600},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6148829408},{"value":0},{"value":0},{"value":169984},{"value":169984},{"value":172032},{"value":6148828912},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6148828720},"sp":{"value":6148828576},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133461,"name":"org.swift.llbuild Lane-7","threadState":{"x":[{"value":4},{"value":0},{"value":4294967295},{"value":6149394792},{"value":1},{"value":0},{"value":0},{"value":1027},{"value":0},{"value":42949672963},{"value":34359738371},{"value":4},{"value":1124073474},{"value":53024468952},{"value":1124073476},{"value":8304884168,"symbolLocation":0,"symbol":"_NSConcreteMallocBlock"},{"value":230},{"value":8328116584},{"value":0},{"value":6149400152},{"value":53022448112},{"value":1},{"value":6149396000},{"value":6149400152},{"value":52990048768},{"value":25},{"value":0},{"value":6149400096},{"value":6149400240}],"flavor":"ARM_THREAD_STATE64","lr":{"value":4342366304},"cpsr":{"value":1610612736},"fp":{"value":6149400368},"sp":{"value":6149395632},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483424960},"far":{"value":0}},"frames":[{"imageOffset":38592,"symbol":"poll","symbolLocation":8,"imageIndex":49},{"imageOffset":508000,"symbol":"llbuild::basic::spawnProcess(llbuild::basic::ProcessDelegate&, llbuild::basic::ProcessContext*, llbuild::basic::ProcessGroup&, llbuild::basic::ProcessHandle, llvm::ArrayRef<llvm::StringRef>, llbuild::basic::POSIXEnvironment, llbuild::basic::ProcessAttributes, std::__1::function<void (std::__1::function<void ()>&&)>&&, std::__1::function<void (llbuild::basic::ProcessResult)>&&)","symbolLocation":2900,"imageIndex":17},{"imageOffset":479940,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeProcess(llbuild::basic::QueueJobContext*, llvm::ArrayRef<llvm::StringRef>, llvm::ArrayRef<std::__1::pair<llvm::StringRef, llvm::StringRef>>, llbuild::basic::ProcessAttributes, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>, llbuild::basic::ProcessDelegate*)","symbolLocation":996,"imageIndex":17},{"imageOffset":530064,"symbol":"llbuild::core::TaskInterface::spawn(llbuild::basic::QueueJobContext*, llvm::ArrayRef<llvm::StringRef>, llvm::ArrayRef<std::__1::pair<llvm::StringRef, llvm::StringRef>>, llbuild::basic::ProcessAttributes, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>, llbuild::basic::ProcessDelegate*)","symbolLocation":164,"imageIndex":17},{"imageOffset":587584,"symbol":"llbuild::buildsystem::ShellCommand::executeExternalCommand(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, llvm::Optional<std::__1::function<void (llbuild::basic::ProcessResult)>>)","symbolLocation":800,"imageIndex":17},{"imageOffset":597532,"symbol":"llbuild::buildsystem::ExternalCommand::execute(llbuild::buildsystem::BuildSystem&, llbuild::core::TaskInterface, llbuild::basic::QueueJobContext*, std::__1::function<void (llbuild::buildsystem::BuildValue&&)>)","symbolLocation":792,"imageIndex":17},{"imageOffset":689784,"symbol":"(anonymous namespace)::CommandTask::inputsAvailable(llbuild::core::TaskInterface)::'lambda'(llbuild::basic::QueueJobContext*)::operator()(llbuild::basic::QueueJobContext*)","symbolLocation":200,"imageIndex":17},{"imageOffset":477744,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":760,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133462,"name":"org.swift.llbuild Lane-8","threadState":{"x":[{"value":260},{"value":0},{"value":170240},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6149975480},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6149976288},{"value":0},{"value":0},{"value":170240},{"value":170240},{"value":172288},{"value":6149975792},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6149975600},"sp":{"value":6149975456},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]},{"id":133463,"name":"org.swift.llbuild Lane-9","threadState":{"x":[{"value":4},{"value":0},{"value":169728},{"value":0},{"value":0},{"value":160},{"value":0},{"value":0},{"value":6150548920},{"value":0},{"value":102912},{"value":442003674468866},{"value":442003674468866},{"value":102912},{"value":0},{"value":442003674468864},{"value":305},{"value":8328123592},{"value":0},{"value":53022447992},{"value":53022448056},{"value":6150549728},{"value":0},{"value":0},{"value":169728},{"value":169728},{"value":171520},{"value":6150549232},{"value":1}],"flavor":"ARM_THREAD_STATE64","lr":{"value":6483665116},"cpsr":{"value":1610612736},"fp":{"value":6150549040},"sp":{"value":6150548896},"esr":{"value":1442840704,"description":"(Syscall)"},"pc":{"value":6483404024},"far":{"value":0}},"frames":[{"imageOffset":17656,"symbol":"__psynch_cvwait","symbolLocation":8,"imageIndex":49},{"imageOffset":28892,"symbol":"_pthread_cond_wait","symbolLocation":984,"imageIndex":54},{"imageOffset":141132,"symbol":"std::__1::condition_variable::wait(std::__1::unique_lock<std::__1::mutex>&)","symbolLocation":32,"imageIndex":55},{"imageOffset":477276,"symbol":"(anonymous namespace)::LaneBasedExecutionQueue::executeLane(unsigned int, unsigned int)","symbolLocation":292,"imageIndex":17},{"imageOffset":486108,"symbol":"void* std::__1::__thread_proxy[abi:nn200100]<std::__1::tuple<std::__1::unique_ptr<std::__1::__thread_struct, std::__1::default_delete<std::__1::__thread_struct>>, void ((anonymous namespace)::LaneBasedExecutionQueue::*)(unsigned int, unsigned int), (anonymous namespace)::LaneBasedExecutionQueue*, unsigned int, unsigned int>>(void*)","symbolLocation":76,"imageIndex":17},{"imageOffset":27656,"symbol":"_pthread_start","symbolLocation":136,"imageIndex":54},{"imageOffset":7080,"symbol":"thread_start","symbolLocation":8,"imageIndex":54}]}],
  "usedImages" : [
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4330078208,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBBuildService",
    "size" : 16384,
    "uuid" : "0075e263-f7fa-39d3-afdc-b23c40f86418",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/MacOS\/SWBBuildService",
    "name" : "SWBBuildService",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4335452160,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBBuildService.Framework",
    "size" : 475136,
    "uuid" : "a947d678-e527-3e00-868e-cea271941cb9",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBBuildService.framework\/Versions\/A\/SWBBuildService",
    "name" : "SWBBuildService",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4331143168,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBCAS",
    "size" : 81920,
    "uuid" : "e9392a37-b77e-3282-9536-22f812b2dce8",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBCAS.framework\/Versions\/A\/SWBCAS",
    "name" : "SWBCAS",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4355801088,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBCore",
    "size" : 4145152,
    "uuid" : "8e72be42-defb-3b2f-a6b0-00aad8cb5d74",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBCore.framework\/Versions\/A\/SWBCore",
    "name" : "SWBCore",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4331356160,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBUtil",
    "size" : 1277952,
    "uuid" : "b6d7b85d-c7dc-37e4-a53d-f51c44b4afb3",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBUtil.framework\/Versions\/A\/SWBUtil",
    "name" : "SWBUtil",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4338253824,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBBuildSystem",
    "size" : 262144,
    "uuid" : "8503b13d-8eae-3996-94a1-ab1d9522ce1f",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBBuildSystem.framework\/Versions\/A\/SWBBuildSystem",
    "name" : "SWBBuildSystem",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4334321664,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBMacro",
    "size" : 212992,
    "uuid" : "e0ffb1c9-251e-35c4-9f6f-9647eecba93e",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBMacro.framework\/Versions\/A\/SWBMacro",
    "name" : "SWBMacro",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4345544704,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBProtocol",
    "size" : 933888,
    "uuid" : "a62281cc-93d5-3a4b-a5c4-8f49a61f5a87",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBProtocol.framework\/Versions\/A\/SWBProtocol",
    "name" : "SWBProtocol",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4336844800,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBServiceCore",
    "size" : 49152,
    "uuid" : "f00dabd3-1a3a-3311-a3c7-9aad34a2969b",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBServiceCore.framework\/Versions\/A\/SWBServiceCore",
    "name" : "SWBServiceCore",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4349018112,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBTaskConstruction",
    "size" : 1556480,
    "uuid" : "8177d38c-7c50-3e2a-af0b-ecabe763398c",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBTaskConstruction.framework\/Versions\/A\/SWBTaskConstruction",
    "name" : "SWBTaskConstruction",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4351836160,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBTaskExecution",
    "size" : 1196032,
    "uuid" : "c423ec04-26a8-37d4-9a5f-7bd9981f581f",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBTaskExecution.framework\/Versions\/A\/SWBTaskExecution",
    "name" : "SWBTaskExecution",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4330897408,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBCSupport",
    "size" : 32768,
    "uuid" : "ef9b58e7-cb44-392d-9546-99d5be6883b3",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBCSupport.framework\/Versions\/A\/SWBCSupport",
    "name" : "SWBCSupport",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4330979328,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBLibc",
    "size" : 16384,
    "uuid" : "96555d63-92cc-3f38-b67b-ad9421dba902",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBLibc.framework\/Versions\/A\/SWBLibc",
    "name" : "SWBLibc",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4330831872,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBCLibc",
    "size" : 16384,
    "uuid" : "127ead11-0ca5-3432-b25b-5a8f09ba10e0",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBCLibc.framework\/Versions\/A\/SWBCLibc",
    "name" : "SWBCLibc",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4365221888,
    "size" : 2424832,
    "uuid" : "0be8cb94-7bab-3f90-899e-0e3e53c3e4be",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/libSwiftDriver.dylib",
    "name" : "libSwiftDriver.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4330733568,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBLLBuild",
    "size" : 16384,
    "uuid" : "d4808d10-7f30-3f88-96e4-98569593c679",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/Frameworks\/SWBLLBuild.framework\/Versions\/A\/SWBLLBuild",
    "name" : "SWBLLBuild",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4337008640,
    "size" : 835584,
    "uuid" : "be3e8444-324b-3e8c-9d56-0ce565a558df",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/libSwiftToolsSupport.dylib",
    "name" : "libSwiftToolsSupport.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341858304,
    "CFBundleShortVersionString" : "1.0",
    "CFBundleIdentifier" : "com.apple.dt.llbuild",
    "size" : 786432,
    "uuid" : "84a22704-fd19-3d76-b7fb-e0282dbc2bf0",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/llbuild.framework\/Versions\/A\/llbuild",
    "name" : "llbuild",
    "CFBundleVersion" : "24000.0.54"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340449280,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBAndroidPlatformPlugin",
    "size" : 16384,
    "uuid" : "19eb5c35-d7fd-311b-ab59-1fc2db4044e7",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBAndroidPlatformPlugin.bundle\/Contents\/MacOS\/SWBAndroidPlatformPlugin",
    "name" : "SWBAndroidPlatformPlugin",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341071872,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBAndroidPlatform",
    "size" : 98304,
    "uuid" : "9a34eb92-bc15-3b46-8593-067eec97d919",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBAndroidPlatformPlugin.bundle\/Contents\/Frameworks\/SWBAndroidPlatform.framework\/Versions\/A\/SWBAndroidPlatform",
    "name" : "SWBAndroidPlatform",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340514816,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBApplePlatformPlugin",
    "size" : 16384,
    "uuid" : "7a14f86d-ab3e-3da1-a363-c1ee8be14ec2",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBApplePlatformPlugin.bundle\/Contents\/MacOS\/SWBApplePlatformPlugin",
    "name" : "SWBApplePlatformPlugin",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4343300096,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBApplePlatform",
    "size" : 409600,
    "uuid" : "8760cd0c-0526-31ed-901a-317bbb0c2f07",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBApplePlatformPlugin.bundle\/Contents\/Frameworks\/SWBApplePlatform.framework\/Versions\/A\/SWBApplePlatform",
    "name" : "SWBApplePlatform",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340580352,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBGenericUnixPlatformPlugin",
    "size" : 16384,
    "uuid" : "93512467-c2ed-3d10-82e1-e67327499a79",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBGenericUnixPlatformPlugin.bundle\/Contents\/MacOS\/SWBGenericUnixPlatformPlugin",
    "name" : "SWBGenericUnixPlatformPlugin",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341350400,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBGenericUnixPlatform",
    "size" : 49152,
    "uuid" : "d42f34a1-76be-3cd0-a908-21cdfbe0b459",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBGenericUnixPlatformPlugin.bundle\/Contents\/Frameworks\/SWBGenericUnixPlatform.framework\/Versions\/A\/SWBGenericUnixPlatform",
    "name" : "SWBGenericUnixPlatform",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340645888,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBQNXPlatformPlugin",
    "size" : 16384,
    "uuid" : "49c1fcd3-2222-3036-be4f-35e06518c6c7",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBQNXPlatformPlugin.bundle\/Contents\/MacOS\/SWBQNXPlatformPlugin",
    "name" : "SWBQNXPlatformPlugin",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341514240,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBQNXPlatform",
    "size" : 49152,
    "uuid" : "12d9237c-df5f-36e0-b4f4-694aa3bf508e",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBQNXPlatformPlugin.bundle\/Contents\/Frameworks\/SWBQNXPlatform.framework\/Versions\/A\/SWBQNXPlatform",
    "name" : "SWBQNXPlatform",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340711424,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBUniversalPlatformPlugin",
    "size" : 16384,
    "uuid" : "4118fb3b-59f0-367b-a691-a0bb53bf752f",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBUniversalPlatformPlugin.bundle\/Contents\/MacOS\/SWBUniversalPlatformPlugin",
    "name" : "SWBUniversalPlatformPlugin",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340776960,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBUniversalPlatform",
    "size" : 49152,
    "uuid" : "ac9e0ad7-1ad3-3e08-9d7d-330e648a11c6",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBUniversalPlatformPlugin.bundle\/Contents\/Frameworks\/SWBUniversalPlatform.framework\/Versions\/A\/SWBUniversalPlatform",
    "name" : "SWBUniversalPlatform",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340989952,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBWebAssemblyPlatformPlugin",
    "size" : 16384,
    "uuid" : "6df45e7f-ac14-316a-bf27-5ec9683e342a",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBWebAssemblyPlatformPlugin.bundle\/Contents\/MacOS\/SWBWebAssemblyPlatformPlugin",
    "name" : "SWBWebAssemblyPlatformPlugin",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4340334592,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBWebAssemblyPlatform",
    "size" : 32768,
    "uuid" : "6407ea7f-92c0-36e2-a943-fd41722b6e9a",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBWebAssemblyPlatformPlugin.bundle\/Contents\/Frameworks\/SWBWebAssemblyPlatform.framework\/Versions\/A\/SWBWebAssemblyPlatform",
    "name" : "SWBWebAssemblyPlatform",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4341792768,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBWindowsPlatformPlugin",
    "size" : 16384,
    "uuid" : "b53c01c5-9203-389f-b5cb-e73366de1cef",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBWindowsPlatformPlugin.bundle\/Contents\/MacOS\/SWBWindowsPlatformPlugin",
    "name" : "SWBWindowsPlatformPlugin",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4344922112,
    "CFBundleShortVersionString" : "16.0",
    "CFBundleIdentifier" : "com.apple.dt.SWBWindowsPlatform",
    "size" : 49152,
    "uuid" : "35e40f47-de15-3e45-82e6-30ff3266ff7a",
    "path" : "\/Applications\/Xcode.app\/Contents\/SharedFrameworks\/SwiftBuild.framework\/Versions\/A\/PlugIns\/SWBBuildService.bundle\/Contents\/PlugIns\/SWBWindowsPlatformPlugin.bundle\/Contents\/Frameworks\/SWBWindowsPlatform.framework\/Versions\/A\/SWBWindowsPlatform",
    "name" : "SWBWindowsPlatform",
    "CFBundleVersion" : "24000.1.210"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4498833408,
    "size" : 6651904,
    "uuid" : "5a42c6a3-f972-32e7-a651-058d926a965b",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/usr\/lib\/libToolchainCASPlugin.dylib",
    "name" : "libToolchainCASPlugin.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4785176576,
    "size" : 88752128,
    "uuid" : "d2c6e450-7eb0-3251-988c-8eef79c6b1b3",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/libclang.dylib",
    "name" : "libclang.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4515037184,
    "size" : 127582208,
    "uuid" : "efb5a9d4-8ff8-32cb-93d9-fa64de9513ea",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_InternalSwiftScan.dylib",
    "name" : "lib_InternalSwiftScan.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4683317248,
    "size" : 65536,
    "uuid" : "45db6512-1468-3976-9459-07d7bafebb8e",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftIDEUtils.dylib",
    "name" : "lib_CompilerSwiftIDEUtils.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4685430784,
    "size" : 262144,
    "uuid" : "2800b377-f531-3978-9ecb-209ca3331878",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftCompilerPluginMessageHandling.dylib",
    "name" : "lib_CompilerSwiftCompilerPluginMessageHandling.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4682530816,
    "size" : 147456,
    "uuid" : "b20d2d64-7837-3b43-a54d-8453523c93f7",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftSyntaxMacroExpansion.dylib",
    "name" : "lib_CompilerSwiftSyntaxMacroExpansion.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4684021760,
    "size" : 49152,
    "uuid" : "c4039a42-47aa-3edc-9c74-5dc225052c6e",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftSyntaxMacros.dylib",
    "name" : "lib_CompilerSwiftSyntaxMacros.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4685004800,
    "size" : 131072,
    "uuid" : "0f31ca8a-2250-38c6-8c5d-29eaa669f633",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftLexicalLookup.dylib",
    "name" : "lib_CompilerSwiftLexicalLookup.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4684185600,
    "size" : 131072,
    "uuid" : "38c3941a-bc9c-3ad4-9067-91110b5befa2",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftIfConfig.dylib",
    "name" : "lib_CompilerSwiftIfConfig.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4687446016,
    "size" : 98304,
    "uuid" : "93806371-9d52-36f3-b52b-58a10136e16f",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftOperators.dylib",
    "name" : "lib_CompilerSwiftOperators.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4690296832,
    "size" : 196608,
    "uuid" : "56187966-1c32-34df-b6af-7c8a4f68ab44",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftSyntaxBuilder.dylib",
    "name" : "lib_CompilerSwiftSyntaxBuilder.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4688019456,
    "size" : 344064,
    "uuid" : "dc767e0f-3139-3e4e-9428-5750d2f31677",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftParserDiagnostics.dylib",
    "name" : "lib_CompilerSwiftParserDiagnostics.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4696276992,
    "size" : 983040,
    "uuid" : "9c3ebeda-88e0-3958-bc3f-974a41232a3f",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftParser.dylib",
    "name" : "lib_CompilerSwiftParser.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4689461248,
    "size" : 65536,
    "uuid" : "539ed3fb-05fb-37cd-b6a7-ef42440be838",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftBasicFormat.dylib",
    "name" : "lib_CompilerSwiftBasicFormat.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4683710464,
    "size" : 81920,
    "uuid" : "304ffbb0-f705-31d2-beb4-ff78c14ee394",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftDiagnostics.dylib",
    "name" : "lib_CompilerSwiftDiagnostics.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64",
    "base" : 4723179520,
    "size" : 2949120,
    "uuid" : "b9313ebc-5057-3a72-9eab-d27484b3470a",
    "path" : "\/Applications\/Xcode.app\/Contents\/Developer\/Toolchains\/XcodeDefault.xctoolchain\/usr\/lib\/swift\/host\/compiler\/lib_CompilerSwiftSyntax.dylib",
    "name" : "lib_CompilerSwiftSyntax.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 4755423232,
    "CFBundleShortVersionString" : "3.0",
    "CFBundleIdentifier" : "com.apple.security.csparser",
    "size" : 131072,
    "uuid" : "7d2e7f9c-0502-33e9-85d0-fb94391908c5",
    "path" : "\/System\/Library\/Frameworks\/Security.framework\/Versions\/A\/PlugIns\/csparser.bundle\/Contents\/MacOS\/csparser",
    "name" : "csparser",
    "CFBundleVersion" : "61901.40.74.0.1"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 6483386368,
    "size" : 246944,
    "uuid" : "fef6120d-486d-336f-bdb7-6726a8470164",
    "path" : "\/usr\/lib\/system\/libsystem_kernel.dylib",
    "name" : "libsystem_kernel.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 6483922944,
    "CFBundleShortVersionString" : "6.9",
    "CFBundleIdentifier" : "com.apple.CoreFoundation",
    "size" : 5532160,
    "uuid" : "2d53b2a7-982b-35d0-8a48-d9abd271e3f6",
    "path" : "\/System\/Library\/Frameworks\/CoreFoundation.framework\/Versions\/A\/CoreFoundation",
    "name" : "CoreFoundation",
    "CFBundleVersion" : "4108"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 10666389504,
    "size" : 563856,
    "uuid" : "75bbae83-0f68-3468-98c8-341e43ee29c1",
    "path" : "\/usr\/lib\/swift\/libswift_Concurrency.dylib",
    "name" : "libswift_Concurrency.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 6479663104,
    "size" : 651112,
    "uuid" : "332c49eb-6f8b-32d6-b9f4-88f99cc8f003",
    "path" : "\/usr\/lib\/dyld",
    "name" : "dyld"
  },
  {
    "size" : 0,
    "source" : "A",
    "base" : 0,
    "uuid" : "00000000-0000-0000-0000-000000000000"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 6483636224,
    "size" : 51900,
    "uuid" : "f37b8a66-9bab-32a0-b222-76d650a69d19",
    "path" : "\/usr\/lib\/system\/libsystem_pthread.dylib",
    "name" : "libsystem_pthread.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 6482673664,
    "size" : 601684,
    "uuid" : "2b3315df-0e29-33bf-9c56-16de7636ff10",
    "path" : "\/usr\/lib\/libc++.1.dylib",
    "name" : "libc++.1.dylib"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 6509391872,
    "CFBundleShortVersionString" : "6.9",
    "CFBundleIdentifier" : "com.apple.Foundation",
    "size" : 16309344,
    "uuid" : "20052a64-6414-35c2-a85b-6ded628cf1b2",
    "path" : "\/System\/Library\/Frameworks\/Foundation.framework\/Versions\/C\/Foundation",
    "name" : "Foundation",
    "CFBundleVersion" : "4108"
  },
  {
    "source" : "P",
    "arch" : "arm64e",
    "base" : 6481833984,
    "size" : 290464,
    "uuid" : "57fb5b7e-54d3-3c19-aa16-2c6470fed988",
    "path" : "\/usr\/lib\/system\/libdispatch.dylib",
    "name" : "libdispatch.dylib"
  }
],
  "sharedCache" : {
  "base" : 6478577664,
  "size" : 5585731584,
  "uuid" : "962add32-782a-3dc3-8f66-c0d63373a8e0"
},
  "vmSummary" : "ReadOnly portion of Libraries: Total=1.2G resident=0K(0%) swapped_out_or_unallocated=1.2G(100%)\nWritable regions: Total=967.3M written=961K(0%) resident=961K(0%) swapped_out=0K(0%) unallocated=966.4M(100%)\n\n                                VIRTUAL   REGION \nREGION TYPE                        SIZE    COUNT (non-coalesced) \n===========                     =======  ======= \nActivity Tracing                   256K        1 \nKernel Alloc Once                   32K        1 \nMALLOC                           882.9M      170 \nMALLOC guard page                 3792K        4 \nSQLite page cache                 60.2M      482 \nSTACK GUARD                       56.4M       24 \nStack                             20.2M       24 \nVM_ALLOCATE                        544K        3 \n__AUTH                            1310K      148 \n__AUTH_CONST                      17.1M      341 \n__CTF                               824        1 \n__DATA                            9548K      351 \n__DATA_CONST                      25.5M      388 \n__DATA_DIRTY                      1332K      286 \n__FONT_DATA                        2352        1 \n__LINKEDIT                       694.9M       50 \n__OBJC_RO                         78.2M        1 \n__OBJC_RW                         2567K        1 \n__TEXT                           512.8M      398 \n__TPRO_CONST                       128K        2 \ndyld private memory                160K        4 \nmapped file                       25.1G       75 \npage table in kernel               961K        1 \nshared memory                     1200K        9 \n===========                     =======  ======= \nTOTAL                             27.4G     2766 \n",
  "legacyInfo" : {
  "threadTriggered" : {
    "queue" : "com.apple.root.default-qos.cooperative"
  }
},
  "logWritingSignature" : "06c58ecba1b7b9000409d5717fefac56babe2c43",
  "trialInfo" : {
  "rollouts" : [
    {
      "rolloutId" : "67181b10c68c361a728c7cfa",
      "factorPackIds" : [

      ],
      "deploymentId" : 250000003
    },
    {
      "rolloutId" : "644114de41e7236e6177f9bd",
      "factorPackIds" : [

      ],
      "deploymentId" : 250000010
    }
  ],
  "experiments" : [

  ]
}
}
