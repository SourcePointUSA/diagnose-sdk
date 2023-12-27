# diagnose-sdk

to build
```bash
./gradlew openApiGenerate
./gradlew build
```

to build simulator xc framework:
```bash
./gradlew linkDiagnoseSdkReleaseFrameworkIosSimulatorArm64
```

to run unit tests:
```bash
./gradlew macosArm64TestBinaries &&  ./build/bin/macosArm64/debugTest/test.kexe
```

to run the hello.kt app
```bash
./gradlew linkHelloDebugExecutableMacosArm64 &&  ./build/bin/macosArm64/helloDebugExecutable/hello.kexe
```