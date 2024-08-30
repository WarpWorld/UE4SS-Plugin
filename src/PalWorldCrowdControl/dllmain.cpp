#include <Mod/CppUserModBase.hpp>
#include <LuaMadeSimple/LuaMadeSimple.hpp>
#include "Connector.h"

class MyAwesomeMod : public RC::CppUserModBase
{
public:
    MyAwesomeMod() : CppUserModBase()
    {
        ModName = STR("Crowd Control");
        ModVersion = STR("1.0.6");
        ModDescription = STR("Crowd Control Support");
        ModAuthors = STR("dtothefourth");
        // Do not change this unless you want to target a UE4SS version
        // other than the one you're currently building with somehow.
        //ModIntendedSDKVersion = STR("2.6");
        
        connector = 0;

    }

    ~MyAwesomeMod() override
    {
        if (connector) connector->Stop();
    }

    static Connector* connector;
    #define CC_IP "127.0.0.1"
    #define CC_PORT "33940"

    static void CrowdControlReconnect()
    {
        if (!connector) return;
	    if (!connector->IsConnected())
	    {
            Output::send<LogLevel::Verbose>(STR("Connecting to Crowd Control\n"));
		    connector->ConnectAsync(CC_PORT);
	    }
	    else if (!connector->IsRunning())
	    {
            Output::send<LogLevel::Verbose>(STR("Running Crowd Control\n"));
		    //connector->Run();
	    }
	    else
	    {

	    }
    }

    static void showEffects(bool show)
    {
        if (!connector || !connector->IsConnected() || !connector->IsRunning()) return;

        int s = 0;

        if (show) s = 0x80;
        else s = 0x81;

        connector->RespondVis("launch", s, "");
        connector->RespondVis("megalaunch", s, "");
        connector->RespondVis("jump", s, "");
        connector->RespondVis("nojump", s, "");
        connector->RespondVis("lowjump", s, "");
        connector->RespondVis("highjump", s, "");
        connector->RespondVis("ultrajump", s, "");
        connector->RespondVis("antigrav", s, "");
        connector->RespondVis("highgrav", s, "");
        connector->RespondVis("lowgrav", s, "");

        connector->RespondVis("base", s, "");
        connector->RespondVis("death", s, "");
        connector->RespondVis("telebegin", s, "");
        connector->RespondVis("teleforgot", s, "");
        connector->RespondVis("teleeast", s, "");
        connector->RespondVis("telereef", s, "");

        connector->RespondVis("freeze", s, "");
        connector->RespondVis("slow", s, "");
        connector->RespondVis("fast", s, "");
        connector->RespondVis("hyper", s, "");

        connector->RespondVis("midnight", s, "");
        connector->RespondVis("morning", s, "");
        connector->RespondVis("noon", s, "");
        connector->RespondVis("evening", s, "");
        connector->RespondVis("hours", s, "");

        connector->RespondVis("kill", s, "");
        connector->RespondVis("heal", s, "");
        connector->RespondVis("fullheal", s, "");
        connector->RespondVis("damage", s, "");
        connector->RespondVis("respawn", s, "");

        connector->RespondVis("fillstam", s, "");
        connector->RespondVis("emptystam", s, "");

        connector->RespondVis("poison", s, "");
        connector->RespondVis("burn", s, "");
        connector->RespondVis("wet", s, "");
        connector->RespondVis("frozen", s, "");
        connector->RespondVis("electrified", s, "");
        connector->RespondVis("muddy", s, "");
        connector->RespondVis("ivy", s, "");

        connector->RespondVis("autocatch", s, "");
        connector->RespondVis("catchup", s, "");
        connector->RespondVis("catchdown", s, "");
        connector->RespondVis("failcatch", s, "");

        connector->RespondVis("attup", s, "");
        connector->RespondVis("attdown", s, "");
        connector->RespondVis("attupbig", s, "");
        connector->RespondVis("attdownbig", s, "");
        connector->RespondVis("defup", s, "");
        connector->RespondVis("defdown", s, "");
        connector->RespondVis("defupbig", s, "");
        connector->RespondVis("defdownbig", s, "");

        connector->RespondVis("expup", s, "");
        connector->RespondVis("expdown", s, "");
        connector->RespondVis("expzero", s, "");
        connector->RespondVis("expfull", s, "");
    }

    auto on_update() -> void override
    {
        //CrowdControlReconnect();
    }

    void on_lua_start(LuaMadeSimple::Lua& lua, LuaMadeSimple::Lua& main_lua, LuaMadeSimple::Lua& async_lua, std::vector<LuaMadeSimple::Lua*>& hook_luas) override
    {
        Output::send<LogLevel::Verbose>(STR("Crowd Control v1.0.6\n"));
        connector = new Connector();
        CrowdControlReconnect();

        lua.register_function("getEffect", [](const LuaMadeSimple::Lua& lua) -> int
        {
            //Output::send<LogLevel::Verbose>(STR("Called testCall From Lua!"));

            auto command = MyAwesomeMod::connector->PopItem();
            if (command == NULL)
            {
                lua.set_integer(-1);
                lua.set_string("");
                lua.set_integer(0);
            }
            else
            {
                lua.set_integer(command.get()->id);
                lua.set_string(command.get()->command);
                lua.set_integer(command.get()->duration);
            }

            return 3;
        });

        lua.register_function("ccRespond", [](const LuaMadeSimple::Lua& lua) -> int
        {

            int32_t stack_size = lua.get_stack_size();

            if (stack_size < 2)
            {
                return 0;
            }

            int id = lua.get_integer();
            int status = lua.get_integer();

            MyAwesomeMod::connector->Respond(id, status, "");

            return 0;
        });

        lua.register_function("connected", [](const LuaMadeSimple::Lua& lua) -> int
        {

            if (!connector || !connector->IsConnected() || !connector->IsRunning())
                lua.set_bool(false);
            else
                lua.set_bool(true);

            return 1;
        });

        lua.register_function("showEffects", [](const LuaMadeSimple::Lua& lua) -> int
        {

            int32_t stack_size = lua.get_stack_size();

            if (stack_size < 1)
            {
                return 0;
            }

            bool show = lua.get_bool();

            showEffects(show);


            return 0;
        });

        lua.register_function("ccRespondTimed", [](const LuaMadeSimple::Lua& lua) -> int
        {

            int32_t stack_size = lua.get_stack_size();

            if (stack_size < 3)
            {
                return 0;
            }

            int id = lua.get_integer();
            int status = lua.get_integer();
            int dur = lua.get_integer();

            MyAwesomeMod::connector->RespondTimed(id, status, "", dur);

            return 0;
        });

        lua.register_function("checkConn", [](const LuaMadeSimple::Lua& lua) -> int
        {

            MyAwesomeMod::CrowdControlReconnect();

            return 0;
        });


        //lua.call_function("blah", 0, 0);
    }
};

#define MY_AWESOME_MOD_API __declspec(dllexport)
extern "C"
{
    MY_AWESOME_MOD_API RC::CppUserModBase* start_mod()
    {
        return new MyAwesomeMod();
    }

    MY_AWESOME_MOD_API void uninstall_mod(RC::CppUserModBase* mod)
    {
        delete mod;
    }
}

Connector* MyAwesomeMod::connector;