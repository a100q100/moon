function os.winSdkVersion()
    local reg_arch = iif( os.is64bit(), "\\Wow6432Node\\", "\\" )
    local sdk_version = os.getWindowsRegistry( "HKLM:SOFTWARE" .. reg_arch .."Microsoft\\Microsoft SDKs\\Windows\\v10.0\\ProductVersion" )
    if sdk_version ~= nil then return sdk_version end
end

workspace "Server"
    configurations { "Debug", "Release" }

    if os.istarget("windows") then
        platforms { "Win32", "x64"}
        characterset ("MBCS")
        systemversion(os.winSdkVersion() .. ".0")
    else
        platforms {"linux"}

    end

    flags{"NoPCH","RelativeLinks"}
    cppdialect "C++17"

    location "./"
    libdirs{"./libs"}

    filter "configurations:Debug"
        defines { "DEBUG" }
        symbols "On"

    filter "configurations:Release"
        defines { "NDEBUG" }
        optimize "On"

    filter { "platforms:Win32" }
        system "windows"
        architecture "x86"

    filter { "platforms:x64" }
        system "windows"
        architecture "x64"

    filter { "platforms:Linux" }
        system "linux"     

 
project "lua53"
    objdir "obj/lua53/%{cfg.platform}_%{cfg.buildcfg}"
    location "build/lua53"
    kind "SharedLib"
    language "C"
    targetdir "bin/%{cfg.buildcfg}"
    includedirs {"./third/lua53"}
    files { "./third/lua53/**.h", "./third/lua53/**.c"}
    removefiles("./third/lua53/luac.c")
    removefiles("./third/lua53/lua.c")
    postbuildcommands{"{COPY} %{wks.location}/bin/%{cfg.buildcfg}/%{cfg.buildtarget.name} %{wks.location}/example/"}
    filter { "system:windows" }
        defines {"LUA_BUILD_AS_DLL"}
    filter { "system:linux" }
        defines {"LUA_USE_LINUX"}
        links{"dl"}

project "rapidjson"
    objdir "obj/rapidjson/%{cfg.platform}_%{cfg.buildcfg}"
    location "build/rapidjson"
    kind "StaticLib"
    language "C++"
    targetdir "bin/%{cfg.buildcfg}"
    includedirs {"./third","./third/rapidjson","./third/rapidjsonlua"} 
    --links{"lua53"}
    files { "./third/rapidjsonlua/**.hpp", "./third/rapidjsonlua/**.cpp"}
    filter {"system:linux"}
        buildoptions {"-msse4.2"}

project "moon"
    objdir "obj/moon/%{cfg.platform}_%{cfg.buildcfg}"
    location "build/moon"
    kind "ConsoleApp"
    language "C++"
    targetdir "bin/%{cfg.buildcfg}"
    includedirs {"./","./moon","./moon/core","./third","./clib"}
    files {"./moon/**.h", "./moon/**.hpp","./moon/**.cpp" }
    links{"lua53","rapidjson"}
    defines {
        "ASIO_STANDALONE" ,
        "ASIO_HAS_STD_ARRAY",
        "ASIO_HAS_STD_TYPE_TRAITS",
        "ASIO_HAS_STD_SHARED_PTR",
        "ASIO_HAS_CSTDINT",
        "ASIO_DISABLE_SERIAL_PORT",
        "ASIO_HAS_STD_CHRONO",
        "ASIO_HAS_MOVE",
        "ASIO_HAS_VARIADIC_TEMPLATES",
        "ASIO_HAS_CONSTEXPR",
        "ASIO_HAS_STD_SYSTEM_ERROR",
        "ASIO_HAS_STD_ATOMIC",
        "ASIO_HAS_STD_FUNCTION",
        "ASIO_HAS_STD_THREAD",
        "ASIO_HAS_STD_MUTEX_AND_CONDVAR",
        "ASIO_HAS_STD_ADDRESSOF",

        "SOL_CHECK_ARGUMENTS"
    }
    postbuildcommands{"{COPY} %{wks.location}/bin/%{cfg.buildcfg}/%{cfg.buildtarget.name} %{wks.location}/example/"}
    filter { "system:windows" }
        defines {"_WIN32_WINNT=0x0601"}
    filter { "system:linux" }
        links{"dl","pthread"} --"-static-libstdc++"
        linkoptions {"-Wl,-rpath=./"}
    filter "configurations:Debug"
        targetsuffix "-d"


--[[
    lua 第三方模块
    @name: LUAMOD name
    @normaladdon : 平台通用的附加项
    @winddowsaddon : windows下的附加项
    @linuxaddon : linux下的附加项

    使用：
    把lua模块源码文件夹放在 third 目录下，确保name和文件夹名字一致
    导出符号：先定义LUA_LIB 使用 LUAMOD_API 导出符号

    注意：
    默认使用C编译器编译，可以使用 *addon 参数进行更改
]]
local function add_third_lua_module( name,normaladdon,winddowsaddon,linuxaddon)
    project(name)
    objdir ("obj/"..name.."/%{cfg.platform}_%{cfg.buildcfg}") --编译生成的中间文件目录
    location ("build/"..name) -- 生成的工程文件目录
    kind "SharedLib" -- 静态库 StaticLib， 动态库 SharedLib
    targetdir "bin/%{cfg.buildcfg}" --目标文件目录
    includedirs {"./third/lua53","./third"} --头文件搜索目录
    files { "./third/"..name.."/**.h", "./third/"..name.."/**.c"} --需要编译的文件， **.c 递归搜索匹配的文件
    targetprefix "" -- linux 下需要去掉动态库 'lib' 前缀
    language "C"
    postbuildcommands{"{COPY} %{wks.location}/bin/%{cfg.buildcfg}/%{cfg.buildtarget.name} %{wks.location}/example/clib/"} -- 编译完后拷贝到example目录
    if type(normaladdon)=="function" then
        normaladdon()
    end
    filter { "system:windows" }
        links{"lua53"} -- windows 版需要链接 lua 库
        defines {"LUA_BUILD_AS_DLL"} -- windows下动态库导出宏定义
        if type(winddowsaddon)=="function" then
            winddowsaddon()
        end
    filter { "system:linux" }
        if type(linuxaddon)=="function" then
            linuxaddon()
        end
end


--[[
    自己编写的lua模块
    @name: LUAMOD name
    @normaladdon : 平台通用的附加项
    @winddowsaddon : windows下的附加项
    @linuxaddon : linux下的附加项

    使用：
    把lua模块源码文件夹放在当前目录的 lualib 目录下，确保name和文件夹名字一致
    导出符号：先定义LUA_LIB 使用 LUAMOD_API 导出符号

    注意：
    默认使用C++编译器编译，可以使用 *addon 参数进行更改
]]
local function add_lua_module( name,normaladdon,winddowsaddon,linuxaddon)
    project(name)
    objdir ("obj/"..name.."/%{cfg.platform}_%{cfg.buildcfg}") --编译生成的中间文件目录
    location ("build/"..name) -- 生成的工程文件目录
    kind "SharedLib" -- 静态库 StaticLib， 动态库 SharedLib
    targetdir "bin/%{cfg.buildcfg}" --目标文件目录
    includedirs {"./third/lua53","./third"} --头文件搜索目录
    files { "./lualib/"..name.."/**.h","./lualib/"..name.."/**.hpp", "./lualib/"..name.."/**.cpp"} --需要编译的文件
    targetprefix "" -- linux 下需要去掉动态库 'lib' 前缀
    language "C++"
    postbuildcommands{"{COPY} %{wks.location}/bin/%{cfg.buildcfg}/%{cfg.buildtarget.name} %{wks.location}/example/clib/"} -- 编译完后拷贝到example目录
    if type(normaladdon)=="function" then
        normaladdon()
    end
    filter { "system:windows" }
        links{"lua53"} -- windows 版需要链接 lua 库
        defines {"LUA_BUILD_AS_DLL"} -- windows下动态库导出宏定义
        if type(winddowsaddon)=="function" then
            winddowsaddon()
        end
    filter { "system:linux" }
        if type(linuxaddon)=="function" then
            linuxaddon()
        end
end

-----------------------------------------------------------------------------------
--[[
    Lua C/C++扩展 在下面添加
]]

-------------------------protobuf--------------------
add_third_lua_module("protobuf",nil,
function ( ... )
    language "C++"
    buildoptions {"/TP"} -- windows 下强制用C++编译，默认会根据文件后缀名选择编译
end)

--[[
    lua版mysql,如果需要lua mysql 客户端，取消下面注释.
    依赖： 需要连接 mysql C client库,
    1. windows 下需要设置MYSQL_HOME.
    2. Linux 下需要确保mysql C client头文件目录和库文件目录正确
]]

-- ---------------------mysql-----------------------
-- add_lua_module("mysql",
-- function( ... )
--     language "C++"
-- end,
-- function ( ... )
--     if os.istarget("windows") then
--         assert(os.getenv("MYSQL_HOME"),"please set mysql environment 'MYSQL_HOME'")
--         includedirs {os.getenv("MYSQL_HOME").. "/include"}
--         libdirs{os.getenv("MYSQL_HOME").. "/lib"} -- 搜索目录
--         links{"libmysql"}
--     end
-- end,
-- function ( ... )
--     if os.istarget("linux") then
--         assert(os.isdir("/usr/include/mysql"),"please make sure you have install mysql, or modify the default include path,'/usr/include/mysql'")
--         assert(os.isdir("/usr/lib64/mysql"),"please make sure you have install mysql, or modify the default lib path,'/usr/lib64/mysql'")
--         includedirs {"/usr/include/mysql"}
--         libdirs{"/usr/lib64/mysql"} -- 搜索目录
--         links{"mysqlclient"}
--     end
-- end
-- )
-- ----------------------------------------------