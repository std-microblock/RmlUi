function Startup()
	maincontext = rmlui.contexts["main"]
	maincontext:LoadDocument("lua_invaders/data/background.html"):Show()
	maincontext:LoadDocument("lua_invaders/data/main_menu.html"):Show()
end

Startup()
