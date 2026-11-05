--  [[ Logged by Hollow Logger https://discord.gg/UWjSZ5ugGJ ]]

local fenv = getfenv()

fenv._W5WJofb = 'VoidedX:0'

local _ = _G.NapoleonCleanup

_G.NapoleonRunId = '8.1207357385936'

writefile('napoleon_bg_v1.png', game:HttpGet(
        [[https://tr.rbxcdn.com/180DAY-c6af2404d410dd3273a96997d7f6a6d4/420/420/Decal/Webp/noFilter]]))

local _callgetcustomasset4 = getcustomasset('napoleon_bg_v1.png')
local _8 = loadstring(game:HttpGet(
        [[https://github.com/Footagesus/WindUI/releases/latest/download/main.lua]]))()
local _wfc9 = game.Players.LocalPlayer:WaitForChild('PlayerGui')
local _callgethui10 = gethui()
local _children11 = game:GetService('CoreGui'):GetChildren()
local _GetChildren13 = _wfc9:GetChildren()
local _GetChildren15 = _callgethui10:GetChildren()
local _Destroy18 = game:GetService('Lighting'):FindFirstChild('NapoleonKeyBlur'):Destroy()
local _Destroy21 = game:GetService('Lighting'):FindFirstChild('NapoleonLoadBlur'):Destroy()
local _Destroy24 = workspace:FindFirstChild('NapoleonHubPredict'):Destroy()
local _Destroy27 = workspace:FindFirstChild('NapoleonClientPredict'):Destroy()
local _Destroy30 = workspace:FindFirstChild('NapoleonReachSphere'):Destroy()
local _gameGetServiceUserInputServiceTouchEnabled31 = game:GetService('UserInputService').TouchEnabled
local _gameGetServiceUserInputServiceKeyboardEnabled32 = game:GetService('UserInputService').KeyboardEnabled
local _Connect35 = game:GetService('RunService').Heartbeat:Connect(function(_36)
        local _ = _G.NapoleonRunId
        local _ = _G.NapoleonRunId
end)
local _Gradient38 = _8:Gradient({
    ['0'] = {
        Color = Color3.new(0.9529412, 0.88235295, 0.68235296),
        Transparency = 0,
    },
    ['100'] = {
        Color = Color3.new(0.47843137, 0.36862746, 0.15686275),
        Transparency = 0,
    },
    ['50'] = {
        Color = Color3.new(0.8117647, 0.68235296, 0.3882353),
        Transparency = 0,
    },
}, {Rotation = 90})
local _Gradient40 = _8:Gradient({
    ['100'] = {
        Color = Color3.new(0.08627451, 0.07058824, 0.050980393),
        Transparency = 0,
    },
    ['0'] = {
        Color = Color3.new(0.17254902, 0.14509805, 0.09803922),
        Transparency = 0,
    },
}, {Rotation = 90})
local _Gradient42 = _8:Gradient({
    ['100'] = {
        Color = Color3.new(0.105882354, 0.08235294, 0.05490196),
        Transparency = 0.1,
    },
    ['0'] = {
        Color = Color3.new(0.03137255, 0.023529412, 0.015686275),
        Transparency = 0.1,
    },
}, {Rotation = 125})
local _AddTheme44 = _8:AddTheme({
    Outline = Color3.new(0.8117647, 0.68235296, 0.3882353),
    ElementBackgroundTransparency = 0.2,
    Button = _Gradient40,
    Background = _Gradient42,
    Icon = Color3.new(0.8784314, 0.7607843, 0.47843137),
    Checkbox = Color3.new(0.8509804, 0.7254902, 0.41568628),
    ElementBackground = Color3.new(0.11372549, 0.09803922, 0.07058824),
    LabelBackgroundTransparency = 0.7,
    LabelBackground = Color3.new(0, 0, 0),
    Text = Color3.new(0.96862745, 0.92941177, 0.84705883),
    Primary = Color3.new(0.8509804, 0.7254902, 0.41568628),
    Dialog = Color3.new(0.043137256, 0.03529412, 0.02745098),
    PanelBackgroundTransparency = 0.18,
    Placeholder = Color3.new(0.5411765, 0.47843137, 0.36078432),
    Name = 'Napoleon',
    PanelBackground = Color3.new(0.0627451, 0.050980393, 0.03529412),
    Slider = Color3.new(0.7882353, 0.6627451, 0.38039216),
    Toggle = Color3.new(0.8509804, 0.7254902, 0.41568628),
    SliderIcon = Color3.new(0.9529412, 0.88235295, 0.68235296),
    Accent = _Gradient38,
})
local _SetTheme46 = _8:SetTheme('Napoleon')
local _UserId53 = game.Players.LocalPlayer.UserId
local _GetService55 = game:GetService('Players').GetUserThumbnailAsync(game:GetService('Players'), 123456789, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
local _wfc62 = game.Players.LocalPlayer.Character:WaitForChild('Humanoid', 5)
local _wfc63 = game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart', 5)
local _Connect66 = game.Players.LocalPlayer.CharacterAdded:Connect(function(_67)
        task.wait(0.2)

        local _WaitForChild69 = _67:WaitForChild('Humanoid', 5)
        local _WaitForChild71 = _67:WaitForChild('HumanoidRootPart', 5)
end)
local _Folder72 = Instance.new('Folder')

_Folder72.Name = 'NapoleonClientPredict'
_Folder72.Parent = workspace

local _descendants73 = workspace:GetDescendants()
local _conn74 = workspace.DescendantAdded:Connect(function(_232)
        local _IsA234 = _232:IsA('BasePart')
        local _lower237 = _232.Name:lower()
end)
local _ffc75 = game:GetService('ReplicatedStorage'):FindFirstChild('CatchBall', true)
local _descendants76 = game:GetService('ReplicatedStorage'):GetDescendants()
local _conn77 = game:GetService('ReplicatedStorage').DescendantAdded:Connect(function(
            _238
        )
        local _IsA240 = _238:IsA('RemoteEvent')
        local _find245 = _238.Name:lower():find('chutar', 1, true)
        local _Connect248 = _238.OnClientEvent:Connect(function()
                local _ = _G.NapoleonRunId
        end)
end)
local _ffc78 = game.Players.LocalPlayer:FindFirstChild('Backpack')
local _GetChildren80 = _ffc78:GetChildren()
local _Connect83 = _ffc78.ChildAdded:Connect(function(_84)
        task.wait(0.1)

        local _IsA86 = _84:IsA('Tool')
        local _find91 = _84.Name:lower():find('chute', 1, true)
        local _Connect94 = _84.Activated:Connect(function()
                local _ = _G.NapoleonRunId
        end)
end)
local _Connect98 = game.Players.LocalPlayer.CharacterAdded:Connect(function(_99)
        task.wait(0.5)

        local _ffc100 = game.Players.LocalPlayer:FindFirstChild('Backpack')
        local _GetChildren102 = _ffc100:GetChildren()
        local _Connect105 = _ffc100.ChildAdded:Connect(function(_106)
                task.wait(0.1)

                local _IsA108 = _106:IsA('Tool')
                local _find113 = _106.Name:lower():find('chute', 1, true)
                local _Connect116 = _106.Activated:Connect(function()
                        local _ = _G.NapoleonRunId
                end)
        end)
        local _GetChildren119 = _99:GetChildren()
        local _Connect122 = _99.ChildAdded:Connect(function(_123)
                task.wait(0.1)

                local _IsA125 = _123:IsA('Tool')
                local _find130 = _123.Name:lower():find('chute', 1, true)
                local _Connect133 = _123.Activated:Connect(function()
                        local _ = _G.NapoleonRunId
                end)
        end)
end)
local _GetDescendants136 = _wfc9:GetDescendants()

_G.NapoleonLoadHub = function()
    local _Destroy140 = game:GetService('Lighting'):FindFirstChild('NapoleonKeyBlur'):Destroy()
    local _callgethui141 = gethui()
    local _children142 = game:GetService('CoreGui'):GetChildren()
    local _GetChildren144 = _wfc9:GetChildren()
    local _GetChildren146 = _callgethui141:GetChildren()

    task.wait(0.3)

    local _150 = loadstring(game:HttpGet(
            [[https://github.com/Footagesus/WindUI/releases/latest/download/main.lua]]))()
    local _Gradient152 = _150:Gradient({
        ['0'] = {
            Color = Color3.new(0.9529412, 0.88235295, 0.68235296),
            Transparency = 0,
        },
        ['100'] = {
            Color = Color3.new(0.47843137, 0.36862746, 0.15686275),
            Transparency = 0,
        },
        ['50'] = {
            Color = Color3.new(0.8117647, 0.68235296, 0.3882353),
            Transparency = 0,
        },
    }, {Rotation = 90})
    local _Gradient154 = _150:Gradient({
        ['100'] = {
            Color = Color3.new(0.08627451, 0.07058824, 0.050980393),
            Transparency = 0,
        },
        ['0'] = {
            Color = Color3.new(0.17254902, 0.14509805, 0.09803922),
            Transparency = 0,
        },
    }, {Rotation = 90})
    local _Gradient156 = _150:Gradient({
        ['100'] = {
            Color = Color3.new(0.105882354, 0.08235294, 0.05490196),
            Transparency = 0.1,
        },
        ['0'] = {
            Color = Color3.new(0.03137255, 0.023529412, 0.015686275),
            Transparency = 0.1,
        },
    }, {Rotation = 125})
    local _AddTheme158 = _150:AddTheme({
        Outline = Color3.new(0.8117647, 0.68235296, 0.3882353),
        ElementBackgroundTransparency = 0.2,
        Button = _Gradient154,
        Background = _Gradient156,
        Icon = Color3.new(0.8784314, 0.7607843, 0.47843137),
        Checkbox = Color3.new(0.8509804, 0.7254902, 0.41568628),
        ElementBackground = Color3.new(0.11372549, 0.09803922, 0.07058824),
        LabelBackgroundTransparency = 0.7,
        LabelBackground = Color3.new(0, 0, 0),
        Text = Color3.new(0.96862745, 0.92941177, 0.84705883),
        Primary = Color3.new(0.8509804, 0.7254902, 0.41568628),
        Dialog = Color3.new(0.043137256, 0.03529412, 0.02745098),
        PanelBackgroundTransparency = 0.18,
        Placeholder = Color3.new(0.5411765, 0.47843137, 0.36078432),
        Name = 'Napoleon',
        PanelBackground = Color3.new(0.0627451, 0.050980393, 0.03529412),
        Slider = Color3.new(0.7882353, 0.6627451, 0.38039216),
        Toggle = Color3.new(0.8509804, 0.7254902, 0.41568628),
        SliderIcon = Color3.new(0.9529412, 0.88235295, 0.68235296),
        Accent = _Gradient152,
    })
    local _SetTheme160 = _150:SetTheme('Napoleon')

    task.wait(0.4)

    local _163 = (workspace.CurrentCamera.ViewportSize.X * 0.92)
end

_G.NapoleonCleanup = function()
    _G.NapoleonRunId = nil
    _G.NapoleonLag = nil

    local _GetService166 = game:GetService('RunService').UnbindFromRenderStep(game:GetService('RunService'), 'NapoleonFollow')
    local _ = _conn74:Disconnect()
    local _ = _conn77:Disconnect()
    local _Disconnect168 = _Connect94:Disconnect()
    local _Disconnect170 = _Connect116:Disconnect()
    local _Disconnect172 = _Connect133:Disconnect()
    local _callgethui173 = gethui()
    local _children174 = game:GetService('CoreGui'):GetChildren()
    local _GetChildren176 = _wfc9:GetChildren()
    local _GetChildren178 = _callgethui173:GetChildren()
    local _dst179 = _Folder72:Destroy()
    local _Destroy182 = game:GetService('Lighting'):FindFirstChild('NapoleonKeyBlur'):Destroy()
    local _Destroy185 = game:GetService('Lighting'):FindFirstChild('NapoleonLoadBlur'):Destroy()
end

local _callgethui187 = gethui()
local _children188 = game:GetService('CoreGui'):GetChildren()
local _GetChildren190 = _wfc9:GetChildren()
local _GetChildren192 = _callgethui187:GetChildren()

task.wait(0.3)

local _196 = loadstring(game:HttpGet(
        [[https://github.com/Footagesus/WindUI/releases/latest/download/main.lua]]))()
local _Gradient198 = _196:Gradient({
    ['0'] = {
        Color = Color3.new(0.9529412, 0.88235295, 0.68235296),
        Transparency = 0,
    },
    ['100'] = {
        Color = Color3.new(0.47843137, 0.36862746, 0.15686275),
        Transparency = 0,
    },
    ['50'] = {
        Color = Color3.new(0.8117647, 0.68235296, 0.3882353),
        Transparency = 0,
    },
}, {Rotation = 90})
local _Gradient200 = _196:Gradient({
    ['100'] = {
        Color = Color3.new(0.08627451, 0.07058824, 0.050980393),
        Transparency = 0,
    },
    ['0'] = {
        Color = Color3.new(0.17254902, 0.14509805, 0.09803922),
        Transparency = 0,
    },
}, {Rotation = 90})
local _Gradient202 = _196:Gradient({
    ['100'] = {
        Color = Color3.new(0.105882354, 0.08235294, 0.05490196),
        Transparency = 0.1,
    },
    ['0'] = {
        Color = Color3.new(0.03137255, 0.023529412, 0.015686275),
        Transparency = 0.1,
    },
}, {Rotation = 125})
local _AddTheme204 = _196:AddTheme({
    Outline = Color3.new(0.8117647, 0.68235296, 0.3882353),
    ElementBackgroundTransparency = 0.2,
    Button = _Gradient200,
    Background = _Gradient202,
    Icon = Color3.new(0.8784314, 0.7607843, 0.47843137),
    Checkbox = Color3.new(0.8509804, 0.7254902, 0.41568628),
    ElementBackground = Color3.new(0.11372549, 0.09803922, 0.07058824),
    LabelBackgroundTransparency = 0.7,
    LabelBackground = Color3.new(0, 0, 0),
    Text = Color3.new(0.96862745, 0.92941177, 0.84705883),
    Primary = Color3.new(0.8509804, 0.7254902, 0.41568628),
    Dialog = Color3.new(0.043137256, 0.03529412, 0.02745098),
    PanelBackgroundTransparency = 0.18,
    Placeholder = Color3.new(0.5411765, 0.47843137, 0.36078432),
    Name = 'Napoleon',
    PanelBackground = Color3.new(0.0627451, 0.050980393, 0.03529412),
    Slider = Color3.new(0.7882353, 0.6627451, 0.38039216),
    Toggle = Color3.new(0.8509804, 0.7254902, 0.41568628),
    SliderIcon = Color3.new(0.9529412, 0.88235295, 0.68235296),
    Accent = _Gradient198,
})
local _SetTheme206 = _196:SetTheme('Napoleon')
local _Gradient208 = _196:Gradient({
    ['0'] = {
        Color = Color3.new(0.9764706, 0.9254902, 0.7529412),
        Transparency = 0,
    },
    ['100'] = {
        Color = Color3.new(0.41960785, 0.32156864, 0.14117648),
        Transparency = 0,
    },
    ['50'] = {
        Color = Color3.new(0.8117647, 0.68235296, 0.3882353),
        Transparency = 0,
    },
}, {Rotation = 90})
local _Gradient210 = _196:Gradient({
    ['100'] = {
        Color = Color3.new(0.08235294, 0.06666667, 0.047058824),
        Transparency = 0,
    },
    ['0'] = {
        Color = Color3.new(0.18039216, 0.15294118, 0.09411765),
        Transparency = 0,
    },
}, {Rotation = 90})
local _Gradient212 = _196:Gradient({
    ['100'] = {
        Color = Color3.new(0.10980392, 0.08627451, 0.0627451),
        Transparency = 0.08,
    },
    ['0'] = {
        Color = Color3.new(0.019607844, 0.015686275, 0.011764706),
        Transparency = 0.08,
    },
}, {Rotation = 135})
local _AddTheme214 = _196:AddTheme({
    Outline = Color3.new(0.8117647, 0.68235296, 0.3882353),
    ElementBackgroundTransparency = 0.18,
    Button = _Gradient210,
    Background = _Gradient212,
    Icon = Color3.new(0.9529412, 0.88235295, 0.68235296),
    Checkbox = Color3.new(0.8509804, 0.7254902, 0.41568628),
})
local _SetTheme216 = _196:SetTheme('NapoleonKeys')
local _SetTheme218 = _196:SetTheme('NapoleonKeys')
local _Destroy221 = game:GetService('Lighting'):FindFirstChild('NapoleonKeyBlur'):Destroy()
local _BlurEffect222 = Instance.new('BlurEffect')

_BlurEffect222.Name = 'NapoleonKeyBlur'
_BlurEffect222.Size = 0
_BlurEffect222.Parent = game:GetService('Lighting')

local _new226 = game:GetService('TweenService').Create(game:GetService('TweenService'), _BlurEffect222, TweenInfo.new(0.6), {Size = 20})
local _Play228 = _new226:Play()

task.wait(0.4)

local _231 = (workspace.CurrentCamera.ViewportSize.X * 0.92)

task.spawn(function()
        local _ = _G.NapoleonRunId
end)
task.spawn(function()
        local _ = _G.NapoleonRunId
end)
task.spawn(function()
        local _ = _G.NapoleonRunId
end)
task.spawn(function()
        local _ = _G.NapoleonRunId
end)
