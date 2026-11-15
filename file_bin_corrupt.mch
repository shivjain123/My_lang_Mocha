function run(didLoad){
    var ft:File = open("test_nm.exe", "read");
    var s:str = ft.read();
    print(s, newLine=true);
};