local i = 0
::loop::
i = i + 1
if i >= 3 then goto done end
goto loop
::done::
print("i=" .. i)
