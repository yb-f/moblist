local mq = require('mq')
local ImGui = require 'ImGui'

local spawns = {}
local running = true
local myName = mq.TLO.Me.DisplayName()
local window_flags = bit32.bor(ImGuiWindowFlags.None)
local treeview_table_flags = bit32.bor(ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg,
    ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Sortable, ImGuiTableFlags.ScrollY)
local openGUI, drawGUI = true, true
local angle = 0
local size = 5
local column_count = 9
local direction_arrow = false

local mobheader = "\ay[\agMob List\ay]"

local updated_data = false

local filter = {
    ['LevelLow'] = 1,
    ['LevelHigh'] = 135,
    ['Name'] = '',
    ['RangeLow'] = 0,
    ['RangeHigh'] = 5000,
    ['Body'] = '',
    ['Race'] = '',
    ['Class'] = '',
    ['Type'] = { 'PC', 'NPC', 'Untargetable', 'Mount', 'Pet', 'Corpse', 'Chest', 'Trigger', 'Trap', 'Timer', 'Item', 'Mercenary', 'Aura', 'Object', 'Banner', 'Campfire', 'Flyer' },
    ['Type_Selected'] = 2,
    ['name_reverse'] = false,
    ['body_reverse'] = false,
    ['race_reverse'] = false,
    ['class_reverse'] = false
}

local ColumnID_ID = 0
local ColumnID_Lvl = 1
local ColumnID_DisplayName = 2
local ColumnID_Name = 3
local ColumnID_Distance = 4
local ColumnID_Loc = 5
local ColumnID_Body = 6
local ColumnID_Race = 7
local ColumnID_Class = 8
local ColumnID_Direction = 9

function RotatePoint(p, cx, cy, angle)
    local radians = math.rad(angle)
    local cosA = math.cos(radians)
    local sinA = math.sin(radians)

    local newX = cosA * (p.x - cx) - sinA * (p.y - cy) + cx
    local newY = sinA * (p.x - cx) + cosA * (p.y - cy) + cy

    return ImVec2(newX, newY)
end

function DrawArrow(topPoint, width, height, color)
    local draw_list = ImGui.GetWindowDrawList()
    local p1 = ImVec2(topPoint.x, topPoint.y)
    local p2 = ImVec2(topPoint.x + width, topPoint.y + height)
    local p3 = ImVec2(topPoint.x - width, topPoint.y + height)

    -- center
    local center_x = (p1.x + p2.x + p3.x) / 3
    local center_y = (p1.y + p2.y + p3.y) / 3

    -- rotate
    angle = angle + .01
    p1 = RotatePoint(p1, center_x, center_y, angle)
    p2 = RotatePoint(p2, center_x, center_y, angle)
    p3 = RotatePoint(p3, center_x, center_y, angle)

    draw_list:AddTriangleFilled(p1, p2, p3, ImGui.GetColorU32(color))
end

local function isType(spawn)
    return spawn.Type() == filter.Type[filter.Type_Selected]
end

local function matchFilters(spawn)
    if not isType(spawn) then return false end
    if not spawn.Type() == filter.Type[filter.Type_Selected] then return false end
    if not (spawn.Level() >= filter.LevelLow and spawn.Level() <= filter.LevelHigh) then return false end
    if not (spawn.Distance() >= filter.RangeLow and spawn.Distance() <= filter.RangeHigh) then return false end
    if filter['name_reverse'] then
        if string.find(string.lower(spawn.Name()), string.lower(filter.Name)) or string.find(string.lower(spawn.DisplayName()), string.lower(filter.Name)) then return false end
    else
        if not string.find(string.lower(spawn.Name()), string.lower(filter.Name)) and not string.find(string.lower(spawn.DisplayName()), string.lower(filter.Name)) then return false end
    end
    if filter['body_reverse'] then
        if string.find(string.lower(spawn.Body()), string.lower(filter.Body)) then return false end
    else
        if not string.find(string.lower(spawn.Body()), string.lower(filter.Body)) then return false end
    end
    if filter['race_reverse'] then
        if string.find(string.lower(spawn.Race()), string.lower(filter.Race)) then return false end
    else
        if not string.find(string.lower(spawn.Race()), string.lower(filter.Race)) then return false end
    end
    if filter['class_reverse'] then
        if string.find(string.lower(spawn.Class()), string.lower(filter.Class)) then return false end
    else
        if not string.find(string.lower(spawn.Class()), string.lower(filter.Class)) then return false end
    end
    return true
end

local function create_spawn_list()
    spawns = mq.getFilteredSpawns(matchFilters)
    updated_data = true
end

local function main()
    create_spawn_list()
    while running == true do
        mq.delay('1s')
        create_spawn_list()
    end
end

local current_sort_specs = nil
local function CompareWithSortSpecs(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0
        if sort_spec.ColumnUserID == ColumnID_ID then
            if a.ID() == nil or b.ID() == nil then return false end
            delta = a.ID() - b.ID()
        elseif sort_spec.ColumnUserID == ColumnID_Lvl then
            if a.Level() == nil or b.Level() == nil then return false end
            delta = a.Level() - b.Level()
        elseif sort_spec.ColumnUserID == ColumnID_DisplayName then
            if a.DisplayName() == nil or b.DisplayName() == nil then return false end
            if a.DisplayName() < b.DisplayName() then
                delta = -1
            elseif b.DisplayName() < a.DisplayName() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Name then
            if a.Name() == nil or b.Name() == nil then return false end
            if a.Name() < b.Name() then
                delta = -1
            elseif b.Name() < a.Name() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Distance then
            if a.Distance() == nil or b.Distance() == nil then return false end
            delta = a.Distance() - b.Distance()
        elseif sort_spec.ColumnUserID == ColumnID_Loc then
            if a.Loc() == nil or b.Loc() == nil then return false end
            if a.Loc() < b.Loc() then
                delta = -1
            elseif b.Loc() < a.Loc() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Body then
            if a.Body() == nil or b.Body() == nil then return false end
            if a.Body() < b.Body() then
                delta = -1
            elseif b.Body() < a.Body() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Race then
            if a.Race() == nil or b.Race() == nil then return false end
            if a.Race() < b.Race() then
                delta = -1
            elseif b.Race() < a.Race() then
                delta = 1
            else
                delta = 0
            end
        elseif sort_spec.ColumnUserID == ColumnID_Class then
            if a.Class() == nil or b.Class() == nil then return false end
            if a.Class() < b.Class() then
                delta = -1
            elseif b.Class() < a.Class() then
                delta = 1
            else
                delta = 0
            end
        end
        if delta ~= 0 then
            if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            end
            return delta > 0
        end
    end
    return a.ID() - b.ID() < 0
end

local function displayGUI()
    if not openGUI then running = false end
    openGUI, drawGUI = ImGui.Begin("Mob List##" .. myName, openGUI, window_flags)
    if drawGUI and not mq.TLO.Me.Zoning() then
        ImGui.Text("Level Range")
        ImGui.SameLine()
        ImGui.PushItemWidth(45)
        filter.LevelLow = ImGui.InputInt('##LowLvl', filter.LevelLow, 0)
        ImGui.SameLine()
        filter.LevelHigh = ImGui.InputInt('##HighLvl', filter.LevelHigh, 0)
        ImGui.PopItemWidth()
        ImGui.SameLine()
        ImGui.Text("Name")
        ImGui.SameLine()
        ImGui.PushItemWidth(200)
        filter.Name = ImGui.InputText('##Name', filter.Name, 0)
        ImGui.PopItemWidth()
        ImGui.SameLine()
        filter['name_reverse'] = ImGui.Checkbox("##NameReverse", filter['name_reverse'])
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Reverse Filter Name')
        end
        ImGui.Text("Distance")
        ImGui.SameLine()
        ImGui.PushItemWidth(50)
        ImGui.SameLine()
        filter.RangeLow = ImGui.InputInt('##RangeLow', filter.RangeLow, 0)
        ImGui.SameLine()
        filter.RangeHigh = ImGui.InputInt('##RangeHigh', filter.RangeHigh, 0)
        ImGui.PopItemWidth()
        ImGui.SameLine()
        ImGui.PushItemWidth(85)
        filter.Type_Selected = ImGui.Combo('##TypeCombo', filter.Type_Selected, filter.Type)
        ImGui.PopItemWidth()
        ImGui.SameLine()
        ImGui.Text("Direction")
        ImGui.SameLine()
        direction_arrow = ImGui.Checkbox("##DirectionArrow", direction_arrow)
        ImGui.SameLine()
        if ImGui.Button("Clear Highlights") then
            mq.cmd('/highlight reset')
        end
        ImGui.Text("Body")
        ImGui.SameLine()
        ImGui.PushItemWidth(100)
        filter.Body = ImGui.InputText('##Body', filter.Body, 0)
        ImGui.PopItemWidth()
        ImGui.SameLine()
        filter['body_reverse'] = ImGui.Checkbox("##BodyReverse", filter['body_reverse'])
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Reverse Filter Body Type')
        end
        ImGui.SameLine()
        ImGui.Text("Race")
        ImGui.SameLine()
        ImGui.PushItemWidth(100)
        filter.Race = ImGui.InputText('##Race', filter.Race, 0)
        ImGui.PopItemWidth()
        ImGui.SameLine()
        filter['race_reverse'] = ImGui.Checkbox("##RaceReverse", filter['race_reverse'])
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Reverse Filter Race')
        end
        ImGui.SameLine()
        ImGui.Text("Class")
        ImGui.SameLine()
        ImGui.PushItemWidth(100)
        filter.Class = ImGui.InputText('##Class', filter.Class, 0)
        ImGui.PopItemWidth()
        ImGui.SameLine()
        filter['class_reverse'] = ImGui.Checkbox("##ClassReverse", filter['class_reverse'])
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip('Reverse Filter Class')
        end

        if direction_arrow == true then
            column_count = 10
        else
            column_count = 9
        end
        if ImGui.BeginTable('##List_table', column_count, treeview_table_flags) then
            ImGui.TableSetupColumn("ID", 0, 50, ColumnID_ID)
            ImGui.TableSetupColumn("Lvl", 0, 30, ColumnID_Lvl)
            ImGui.TableSetupColumn("Display Name", 0, 200, ColumnID_DisplayName)
            ImGui.TableSetupColumn("Name", 0, 200, ColumnID_Name)
            ImGui.TableSetupColumn("Dist", 0, 50, ColumnID_Distance)
            ImGui.TableSetupColumn("Loc", 0, 100, ColumnID_Loc)
            ImGui.TableSetupColumn("Body Type", 0, 80, ColumnID_Body)
            ImGui.TableSetupColumn("Race", 0, 80, ColumnID_Race)
            ImGui.TableSetupColumn("Class", 0, 70, ColumnID_Class)
            if direction_arrow == true then
                ImGui.TableSetupColumn("Direction", ImGuiTableColumnFlags.NoSort, 20, ColumnID_Direction)
            end
            ImGui.TableSetupScrollFreeze(0, 1)
            local sort_specs = ImGui.TableGetSortSpecs()
            if updated_data then
                sort_specs.SpecsDirty = true
                updated_data = false
            end
            if sort_specs then
                if sort_specs.SpecsDirty then
                    for n = 1, sort_specs.SpecsCount, 1 do
                        local sort_spec = sort_specs:Specs(n)
                    end
                    if #spawns > 1 then
                        current_sort_specs = sort_specs
                        table.sort(spawns, CompareWithSortSpecs)
                        current_sort_specs = nil
                    end
                    sort_specs.SpecsDirty = false
                end
            end
            ImGui.TableHeadersRow()
            local clipper = ImGuiListClipper.new()
            clipper:Begin(#spawns)
            while clipper:Step() do
                for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                    local item = spawns[row_n + 1]
                    if item.ID() == nil or item.Level() == nil or item.DisplayName() == nil or item.Name() == nil then break end
                    if item.Distance() == nil or item.Loc() == nil or item.Race() == nil then break end
                    if item.Race() == nil or item.Class() == nil then break end
                    ImGui.PushID(item)
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    ImGui.Selectable(tostring(item.ID()), false, ImGuiSelectableFlags.SpanAllColumns)
                    if ImGui.IsItemHovered() then
                        if ImGui.IsMouseReleased(ImGuiMouseButton.Right) then
                            printf("%s \agHighlighting mobs named \ar%s", mobheader, item.DisplayName())
                            mq.cmdf('/highlight "%s"', item.DisplayName())
                        end
                        if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                            if ImGui.IsKeyDown(ImGuiKey.LeftCtrl) or ImGui.IsKeyPressed(ImGuiKey.RightCtrl) then
                                printf("%s \agNavigating \aogroup \agto \ar%s \ag ID \ar%s", mobheader,
                                    item.DisplayName(),
                                    item.ID())
                                mq.cmdf('/dgae /nav id %s', item.ID())
                            else
                                printf("%s \agNavigating \aoself \agto \ar%s \ag ID \ar%s", mobheader, item.Name(),
                                    item.ID())
                                mq.cmdf('/nav id %s', item.ID())
                            end
                        end
                    end
                    ImGui.TableNextColumn()
                    ImGui.Text(item.Level())
                    ImGui.TableNextColumn()
                    ImGui.Text(item.DisplayName())
                    ImGui.TableNextColumn()
                    ImGui.Text(item.Name())
                    ImGui.TableNextColumn()
                    ImGui.Text(string.format("%.2f", item.Distance()))
                    ImGui.TableNextColumn()
                    ImGui.Text(item.Loc())
                    ImGui.TableNextColumn()
                    ImGui.Text(item.Body())
                    ImGui.TableNextColumn()
                    ImGui.Text(item.Race())
                    ImGui.TableNextColumn()
                    ImGui.Text(item.Class())
                    ImGui.TableNextColumn()
                    if direction_arrow == true then
                        local cursorScreenPos = ImGui.GetCursorScreenPosVec()
                        --angle = getRelativeDirection(item.HeadingTo())
                        angle = item.HeadingTo.Degrees() - mq.TLO.Me.Heading.Degrees()
                        DrawArrow(ImVec2(cursorScreenPos.x + size / 2, cursorScreenPos.y), 5, 15,
                            ImVec4(0, 255, 0, 255))
                    end
                    ImGui.PopID()
                end
            end
        end
        ImGui.EndTable()
    end
    ImGui.End()
end

mq.imgui.init('displayGUI', displayGUI)

main()
