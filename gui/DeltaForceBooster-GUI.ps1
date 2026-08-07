<#
  DeltaForceBooster 图形界面 — v0.12
  视觉基准：三角洲行动国服官网 df.qq.com 实测提炼（用户提供截图）：
    近黑微青顶栏 #0D1417 + 页面青绿细渐变 #0A1512→#10201C + 正绿 CTA #00E884（斜切角 +
    等高线纹理）+ 金色分类标签 #E5C46A + 中英上下叠排分区标题（选中态绿色下划线）
    + 侧边刻度尺装饰 + 等宽技术标注 + 「— — 中 文 拉 字 距 — —」式装饰分隔线。
  v0.12：真机反馈四连修——①体检查出问题（VC++ 错乱/XMP 未开）不再只落纯文本日志：
        执行后弹「体检发现问题」对话框，带逐步教程与可点击的官方下载按钮（链接是代码
        硬编码常量、只放行 https，绝不下载执行），优化项行内也有「解决办法」直达入口；
        ②优化项列表加三态全选框，只圈可执行项（已就绪项不重复执行），手动全选同样清空
        方案选中态；③主播设置参考按游戏内「设置 → 画面」菜单分组（显示设置/战斗视角/
        基础画质/高级画质/超分辨率），照表能逐菜单找到，老格式数据自动归入「其他」；
        ④显卡指引顶部醒目标出检测到的显卡型号（双显卡说明以独显为准），并按型号标注
        DLSS/FSR/XeSS/Reflex/Anti-Lag 的适用范围。
  v0.11：内置更新——更新详情框新增「立即更新」：应用内下载安装包（进度条 + 可取消），
        下载完成强制校验 SHA256 与大小（更新模块 v0.2，域名白名单 + 校验失败即删），
        通过后提示并关闭本程序启动安装器；清单缺校验信息或下载/校验失败时退回
        「跳浏览器打开下载页」的旧行为。更新检查从「仅启动时一次」改为运行期间每
        30 分钟静默复查，运行中出了新版本标题栏入口也会亮起，无需重启软件。
  v0.10：执行优化后若有需重启才完全生效的成功项，弹主题化「需要重启电脑」提醒
        （列出等重启的项，「立即重启」须二次确认后才 shutdown /r /t 5，重启调用包在
        Invoke-SystemReboot 里便于测试替换）；运行日志区新增一键复制小按钮（成功短暂
        变「已复制」，剪贴板被占用时落日志引导手动复制）；还原结果展示引擎新增的
        「跳过（无实际影响）」类别，不再与失败混在一起；窗口挂 gui\app.ico——
        此前任务栏/Alt-Tab 显示的是宿主 powershell.exe 的图标（实机反馈）。
  v0.9：还原设置改为逐项进度反馈（复用执行优化的进度面板，引擎 Invoke-Restore 新增
        可选回调），结束弹主题化完成提示——此前同步跑完才刷新，界面卡一下就结束，
        用户不知道还原有没有真的发生。
  v0.8：全部原生 MessageBox 换成主题化对话框（确认执行/确认还原/确认删除/显卡指引）；
        标题栏新增 Discord 式「有新版本」常驻入口（检测到更新才出现，点击弹主题化详情，
        仍只允许浏览器打开 https 链接）；检测类项目结果改用金色「提示」语义不再计入失败；
        修复主播设置参考页滚轮失灵（内层横向 ScrollViewer 吞掉 MouseWheel，改抛父级冒泡）。
  v0.7：文案从军事黑话改回平实功能名；新增「优化 / 主播设置参考」标签页（参考数据来自
        data\streamer-settings.json，纯展示不可应用）；执行优化改为逐项进度条 + 实时日志
        + 完成度汇总，执行期间按钮全部禁用。
  双击根目录「启动优化工具.exe」（或后备的 .bat）运行；本文件点源加载
  scripts\delta-booster.ps1 作为引擎，scripts\updater.ps1 作为更新模块
  （异步、静默失败；下载仅限白名单域名 + SHA256 校验，且必须用户点击触发）。
#>
#requires -Version 5.1

# HKLM/电源计划等系统级项需要管理员，界面统一提权一次，省去逐项判断
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
  exit
}

$ErrorActionPreference = 'Stop'
$script:RootDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $script:RootDir 'scripts\delta-booster.ps1')

# 界面版本号：标题栏徽标 / 页脚 / 更新检查共用同一处定义，避免三处漂移
$script:GuiVersion = '0.12'
$script:UpdaterPath = Join-Path $script:RootDir 'scripts\updater.ps1'
# 更新模块独立可缺失：老用户手动拷贝升级时可能没有该文件，缺了也不能影响主功能
if (Test-Path -LiteralPath $script:UpdaterPath) { try { . $script:UpdaterPath } catch {} }

Add-Type -AssemblyName PresentationFramework

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="三角洲行动 · 画面优化助手" Width="780" Height="860"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="CanResize"
        BorderBrush="#FF1B2E28" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <!-- 官网页面底色不是纯黑：带青绿调的细微垂直渐变 -->
  <Window.Background>
    <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#FF0A1512" Offset="0"/>
      <GradientStop Color="#FF10201C" Offset="1"/>
    </LinearGradientBrush>
  </Window.Background>
  <Window.Resources>
    <SolidColorBrush x:Key="TopBar"    Color="#FF0D1417"/>
    <SolidColorBrush x:Key="Panel"     Color="#FF0E1B17"/>
    <SolidColorBrush x:Key="PanelDeep" Color="#FF0B1713"/>
    <SolidColorBrush x:Key="LogBg"     Color="#FF081310"/>
    <SolidColorBrush x:Key="Line"      Color="#FF1B2E28"/>
    <SolidColorBrush x:Key="LineSoft"  Color="#FF16241F"/>
    <SolidColorBrush x:Key="LineHi"    Color="#FF2C443B"/>
    <SolidColorBrush x:Key="TextPri"   Color="#FFFFFFFF"/>
    <SolidColorBrush x:Key="TextSec"   Color="#FF9AA5A0"/>
    <SolidColorBrush x:Key="TextMut"   Color="#FF7A8580"/>
    <SolidColorBrush x:Key="Green"     Color="#FF00E884"/>
    <SolidColorBrush x:Key="GreenDark" Color="#FF04241B"/>
    <SolidColorBrush x:Key="GreenLine" Color="#FF17603F"/>
    <SolidColorBrush x:Key="Gold"      Color="#FFE5C46A"/>
    <SolidColorBrush x:Key="GoldDark"  Color="#FF3A2C0C"/>
    <SolidColorBrush x:Key="Danger"    Color="#FFE5484D"/>

    <!-- 官网下载按钮同款：绿色实底之上叠一层略暗的等高线纹路（战术地图质感）。
         用 DrawingBrush 平铺而不是 Path 叠加：笔画粗细不随控件尺寸缩放（教训 #3） -->
    <DrawingBrush x:Key="CtaFill" TileMode="Tile" Viewport="0,0,64,40" ViewportUnits="Absolute"
                  Viewbox="0,0,64,40" ViewboxUnits="Absolute">
      <DrawingBrush.Drawing>
        <DrawingGroup>
          <GeometryDrawing Brush="#FF00E884">
            <GeometryDrawing.Geometry>
              <RectangleGeometry Rect="0,0,64,40"/>
            </GeometryDrawing.Geometry>
          </GeometryDrawing>
          <GeometryDrawing>
            <GeometryDrawing.Pen>
              <Pen Brush="#4C043C28" Thickness="1"/>
            </GeometryDrawing.Pen>
            <GeometryDrawing.Geometry>
              <PathGeometry Figures="M 0,7 C 12,3 22,12 34,8 C 46,4 56,11 64,7 M 0,20 C 10,25 24,15 36,21 C 48,26 58,18 64,20 M 0,33 C 14,29 28,37 42,32 C 52,28 60,35 64,33"/>
            </GeometryDrawing.Geometry>
          </GeometryDrawing>
        </DrawingGroup>
      </DrawingBrush.Drawing>
    </DrawingBrush>

    <Style x:Key="TacCheck" TargetType="CheckBox">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border Background="Transparent" Padding="0,3">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="Box" Width="13" Height="13" BorderBrush="#FF2C443B"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Center">
                  <Grid>
                    <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="#FF04241B"
                          StrokeThickness="2" Visibility="Collapsed"/>
                    <!-- 第三态（部分选中）：绿色小方块。只有全选框会进入此态，
                         普通项复选框永远只在勾/不勾之间切换 -->
                    <Border x:Name="PartMark" Width="7" Height="7" Background="#FF00E884"
                            HorizontalAlignment="Center" VerticalAlignment="Center"
                            Visibility="Collapsed"/>
                  </Grid>
                </Border>
                <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="#FF00E884"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="{x:Null}">
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="PartMark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网次级动作样式：绿色细描边 + 绿色文字 + 内容居中 -->
    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="Foreground" Value="#FF00E884"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网主 CTA：斜切角 + 等高线纹理 + 深色字；hover 用白色薄罩提亮而不是换色，
         保住纹理层不被覆盖 -->
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="Foreground" Value="#FF04241B"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Height" Value="38"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <!-- 几何用 0–1 归一化坐标：Path 的期望尺寸即为 1x1，不会把按钮撑大，Stretch 再拉满 -->
              <Path x:Name="Bg" Stretch="Fill" Fill="{StaticResource CtaFill}"
                    Data="M 0.05,0 L 1,0 L 1,0.8 L 0.95,1 L 0,1 L 0,0.2 Z"/>
              <Path x:Name="Hover" Stretch="Fill" Fill="#FFFFFFFF" Opacity="0"
                    Data="M 0.05,0 L 1,0 L 1,0.8 L 0.95,1 L 0,1 L 0,0.2 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Hover" Property="Opacity" Value="0.16"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#FF9AA5A0"/>
      <Setter Property="Width" Value="34"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="#FF14241F"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网行首分类标签同款：金色实底 + 深色粗体字（官网用于「赛事」「公告」） -->
    <Style x:Key="Chip" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource Gold}"/>
      <Setter Property="Padding" Value="7,1"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="ChipText" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource GoldDark}"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>

    <!-- 中英上下叠排分区标题：中文白粗体在上、小号大写英文在下、绿色短下划线
         （官网标签页选中态：绿色文字 + 底部绿色下划线，这里移植为分区标识） -->
    <Style x:Key="HeadCn" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource TextPri}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style x:Key="HeadEn" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="8"/>
      <Setter Property="Foreground" Value="{StaticResource TextMut}"/>
      <Setter Property="Margin" Value="1,1,0,0"/>
    </Style>
    <Style x:Key="HeadBar" TargetType="Border">
      <Setter Property="Height" Value="2"/>
      <Setter Property="Width" Value="28"/>
      <Setter Property="Background" Value="{StaticResource Green}"/>
      <Setter Property="HorizontalAlignment" Value="Left"/>
      <Setter Property="Margin" Value="0,4,0,0"/>
    </Style>

    <Style x:Key="Mono" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Foreground" Value="{StaticResource TextMut}"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <!-- 标签页按钮：官网标签页手法——选中项绿色文字 + 底部绿色下划线，未选中灰色。
         不用 WPF TabControl：其默认模板白底黑字，整套重模板不如自绘两个按钮可控 -->
    <Style x:Key="TabBtn" TargetType="Button">
      <Setter Property="Foreground" Value="{StaticResource TextSec}"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="16,9,16,11"/>
              <Border x:Name="UL" Height="2" Background="{StaticResource Green}" VerticalAlignment="Bottom"
                      Margin="12,0" Visibility="Collapsed"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Tag" Value="on">
                <Setter TargetName="UL" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="{StaticResource Green}"/>
                <Setter Property="FontWeight" Value="Bold"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="{StaticResource Green}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 侧边刻度尺装饰：官网页面两侧贯穿整屏的细刻度 + 等宽小数字 -->
    <Style x:Key="RulerNum" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="8"/>
      <Setter Property="Foreground" Value="{StaticResource TextMut}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="TickMajor" TargetType="Border">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{StaticResource LineHi}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,5"/>
    </Style>
    <Style x:Key="TickMinor" TargetType="Border">
      <Setter Property="Width" Value="4"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{StaticResource LineSoft}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,5"/>
    </Style>
    <!-- 装饰分隔线的短横段：「— — — 中 文 — — —」 -->
    <Style x:Key="Dash" TargetType="Border">
      <Setter Property="Width" Value="14"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{StaticResource LineHi}"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="4,0"/>
    </Style>

    <!-- 深色滚动条：默认白色滚动条在本主题下非常突兀 -->
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="6"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                </Track.DecreaseRepeatButton>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                </Track.IncreaseRepeatButton>
                <Track.Thumb>
                  <Thumb>
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb">
                        <Border Background="#FF2C443B" CornerRadius="3"/>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 深色主题 ComboBox：默认白底模板在本主题下刺眼，整体重做。
         选中项文字用品牌绿——官网列表强调项就是整行绿色 -->
    <Style x:Key="TacComboItem" TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="#FF9AA5A0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="BD" Background="Transparent" Padding="10,5">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="BD" Property="Background" Value="#FF12291F"/>
                <Setter Property="Foreground" Value="#FF00E884"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="BD" Property="Background" Value="#FF0F2118"/>
                <Setter Property="Foreground" Value="#FF00E884"/>
                <Setter Property="FontWeight" Value="Bold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="TacCombo" TargetType="ComboBox">
      <Setter Property="Foreground" Value="#FF00E884"/>
      <Setter Property="Height" Value="26"/>
      <Setter Property="ItemContainerStyle" Value="{StaticResource TacComboItem}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                            Focusable="False" ClickMode="Press">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="BD" Background="#FF0B1712" BorderBrush="#FF2C443B" BorderThickness="1">
                      <Path Data="M 0,0 L 8,0 L 4,5 Z" Fill="#FF00E884"
                            HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,9,0"/>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="BD" Property="BorderBrush" Value="#FF00E884"/>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                Margin="10,0,26,0" VerticalAlignment="Center" IsHitTestVisible="False"
                                TextBlock.Foreground="{TemplateBinding Foreground}"/>
              <Popup IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom"
                     AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                <Border Background="#FF0E1B17" BorderBrush="#FF2C443B" BorderThickness="1"
                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="220">
                  <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <ItemsPresenter/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- 顶栏：官网近黑微青 #0D1417 -->
    <Border x:Name="TitleBar" Grid.Row="0" Background="{StaticResource TopBar}"
            BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1">
      <Grid>
        <StackPanel Orientation="Horizontal" Margin="14,10">
          <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF00E884" VerticalAlignment="Center"/>
          <TextBlock Text="DELTA FORCE" Foreground="{StaticResource TextPri}" FontSize="13"
                     FontWeight="Bold" Margin="10,0,0,0" VerticalAlignment="Center">
            <TextBlock.LayoutTransform><ScaleTransform ScaleX="1.05"/></TextBlock.LayoutTransform>
          </TextBlock>
          <Border Width="1" Height="13" Background="#FF2C443B" Margin="11,0"/>
          <TextBlock Text="画面优化助手" Foreground="{StaticResource TextSec}" FontSize="12" VerticalAlignment="Center"/>
          <TextBlock Text="[ v0.12 ]" Style="{StaticResource Mono}" Foreground="{StaticResource Green}" Margin="9,0,0,0"/>
        </StackPanel>
        <!-- 等宽技术标注块：官网左上角同款装饰手法，文案用平实说法 -->
        <TextBlock Text="SYS-BOOST" Style="{StaticResource Mono}" FontSize="9"
                   HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,84,0"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <!-- Discord 式更新入口：检测到新版本才出现的小绿胶囊，点击弹更新详情。
               图标用固定坐标小 Path（不加 Stretch）：归一化坐标 + Stretch 会被撑大（教训 #3） -->
          <Button x:Name="UpdateBtn" Visibility="Collapsed" VerticalAlignment="Center" Margin="0,0,10,0"
                  Foreground="#FF04241B" Cursor="Hand">
            <Button.Template>
              <ControlTemplate TargetType="Button">
                <Border x:Name="B" Background="#FF00E884" CornerRadius="10" Padding="9,3">
                  <StackPanel Orientation="Horizontal">
                    <Path Data="M 3,0 L 6,0 L 6,4 L 9,4 L 4.5,9 L 0,4 L 3,4 Z M 0,11 L 9,11 L 9,12.5 L 0,12.5 Z"
                          Fill="#FF04241B" Width="9" Height="13" VerticalAlignment="Center"/>
                    <TextBlock Text="有新版本" FontSize="11" FontWeight="Bold" Foreground="#FF04241B"
                               VerticalAlignment="Center" Margin="6,0,0,0"/>
                  </StackPanel>
                </Border>
                <ControlTemplate.Triggers>
                  <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="B" Property="Background" Value="#FF33F09E"/>
                  </Trigger>
                </ControlTemplate.Triggers>
              </ControlTemplate>
            </Button.Template>
          </Button>
          <Button x:Name="MinBtn" Content="—" Style="{StaticResource WinBtn}"/>
          <Button x:Name="CloseBtn" Content="✕" Style="{StaticResource WinBtn}"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- 标签页导航：优化 / 主播设置参考 -->
    <Border Grid.Row="1" Background="{StaticResource TopBar}" BorderBrush="{StaticResource Line}"
            BorderThickness="0,0,0,1">
      <StackPanel Orientation="Horizontal" Margin="15,0,0,0">
        <Button x:Name="TabOptBtn" Content="优化" Style="{StaticResource TabBtn}" Tag="on"/>
        <Button x:Name="TabRefBtn" Content="主播设置参考" Style="{StaticResource TabBtn}" Tag=""/>
      </StackPanel>
    </Border>

    <Grid Grid.Row="2" x:Name="OptPage">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <!-- 大号淡化 Logo 水印：官网 hero 区同手法 -->
      <Path Grid.Column="1" Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF00E884" Opacity="0.03"
            Stretch="Uniform" Width="420" Height="350" HorizontalAlignment="Right"
            VerticalAlignment="Top" Margin="0,-60,-80,0"/>

      <!-- 左侧刻度尺 -->
      <Grid Grid.Column="0" Width="16" Margin="5,12,0,12">
        <StackPanel VerticalAlignment="Top">
          <TextBlock Text="82" Style="{StaticResource RulerNum}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Bottom">
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <TextBlock Text="42" Style="{StaticResource RulerNum}"/>
        </StackPanel>
      </Grid>

      <!-- 右侧刻度尺 -->
      <Grid Grid.Column="2" Width="16" Margin="0,12,5,12">
        <StackPanel VerticalAlignment="Top">
          <TextBlock Text="72" Style="{StaticResource RulerNum}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Bottom">
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <TextBlock Text="60" Style="{StaticResource RulerNum}"/>
        </StackPanel>
      </Grid>

      <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" Padding="8,6">
        <StackPanel>

          <!-- 分区标题：中英上下叠排 + 绿色短下划线 -->
          <Grid Margin="0,2,0,8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="系统信息" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="SYSTEM INFO" Style="{StaticResource HeadEn}"/>
              <Border Style="{StaticResource HeadBar}"/>
            </StackPanel>
            <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                    VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <TextBlock Grid.Column="2" x:Name="ScanState" Text="检测中…" Style="{StaticResource Mono}"
                       Foreground="{StaticResource Green}" VerticalAlignment="Bottom" Margin="0,0,0,2"/>
          </Grid>

          <UniformGrid x:Name="HwGrid" Columns="3" Margin="0,0,0,7"/>

          <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}"
                  BorderThickness="1" Padding="8,4" Margin="0,0,0,11">
            <StackPanel Orientation="Horizontal">
              <Border Style="{StaticResource Chip}">
                <TextBlock Text="目标程序" Style="{StaticResource ChipText}"/>
              </Border>
              <TextBlock x:Name="GameText" Text="定位中…" Style="{StaticResource Mono}"
                         Foreground="{StaticResource TextPri}" Margin="10,0,0,0"
                         TextTrimming="CharacterEllipsis" MaxWidth="470"/>
              <Button x:Name="BrowseBtn" Content="重新定位" Style="{StaticResource Ghost}"
                      Margin="12,0,0,0" FontSize="11" Height="24"/>
            </StackPanel>
          </Border>

          <Grid Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="优化项" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="OPTIMIZATION ITEMS" Style="{StaticResource HeadEn}"/>
              <Border Style="{StaticResource HeadBar}"/>
            </StackPanel>
            <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                    VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <TextBlock Grid.Column="2" x:Name="CountText" Text="" Style="{StaticResource Mono}"
                       Foreground="{StaticResource TextSec}" VerticalAlignment="Bottom" Margin="0,0,0,2"/>
          </Grid>

          <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}"
                  BorderThickness="1" Padding="8,4" Margin="0,0,0,4">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Style="{StaticResource Chip}">
                <TextBlock Text="预设方案" Style="{StaticResource ChipText}"/>
              </Border>
              <ComboBox x:Name="PresetBox" Grid.Column="1" Margin="10,0,10,0" Style="{StaticResource TacCombo}"/>
              <Button x:Name="SavePresetBtn" Grid.Column="2" Content="存为方案"
                      Style="{StaticResource Ghost}" FontSize="11" Height="24"/>
              <Button x:Name="DelPresetBtn" Grid.Column="3" Content="删除"
                      Style="{StaticResource Ghost}" FontSize="11" Height="24" Margin="7,0,0,0"/>
            </Grid>
          </Border>

          <TextBlock x:Name="PresetNote" Text="" Style="{StaticResource Mono}"
                     TextTrimming="CharacterEllipsis" Margin="2,0,0,4"/>

          <Border BorderBrush="{StaticResource Line}" BorderThickness="1" Background="{StaticResource PanelDeep}">
            <StackPanel>
              <!-- 全选行（实机诉求）：三态仅作展示——部分选中显示第三态，点击只在
                   全选/全不选之间切换；只圈「可执行」项，已就绪项重复执行只会撑大备份 -->
              <Border Background="#FF0C1915" BorderBrush="{StaticResource LineSoft}"
                      BorderThickness="0,0,0,1" Padding="10,3">
                <Grid>
                  <CheckBox x:Name="SelAllChk" Style="{StaticResource TacCheck}" VerticalAlignment="Center">
                    <TextBlock Text="全选" Foreground="#FFFFFFFF" FontSize="12" FontWeight="Bold"/>
                  </CheckBox>
                  <TextBlock Text="只圈可执行项 · 已就绪的不重复执行" FontFamily="Consolas" FontSize="10"
                             Foreground="{StaticResource TextMut}" HorizontalAlignment="Right"
                             VerticalAlignment="Center"/>
                </Grid>
              </Border>
              <StackPanel x:Name="ItemPanel"/>
            </StackPanel>
          </Border>

          <Expander x:Name="RiskyGroup" Margin="0,10,0,0" Visibility="Collapsed" Foreground="{StaticResource Danger}">
            <Expander.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="危险区域" Foreground="{StaticResource Danger}" FontSize="12"/>
                <TextBlock Text="降低系统安全性，需二次确认" Style="{StaticResource Mono}" Margin="10,0,0,0"/>
              </StackPanel>
            </Expander.Header>
            <Border BorderBrush="#FF4A2420" BorderThickness="1" Background="#FF17100F" Margin="0,6,0,0">
              <StackPanel x:Name="RiskyPanel"/>
            </Border>
          </Expander>

          <!-- 官网招牌装饰分隔线：两侧短横段 + 中间拉开字距的中文 -->
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,14,0,4">
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <TextBlock Text="系 统 优 化 · 改 前 备 份 · 一 键 还 原" Foreground="{StaticResource TextMut}"
                       FontSize="10" Margin="10,0" VerticalAlignment="Center"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
          </StackPanel>

        </StackPanel>
      </ScrollViewer>
    </Grid>

    <!-- 主播设置参考页：纯展示（内容由代码按 data\streamer-settings.json 构建） -->
    <Grid Grid.Row="2" x:Name="RefPage" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="21,10">
        <StackPanel x:Name="RefPanel"/>
      </ScrollViewer>
    </Grid>

    <StackPanel Grid.Row="3" x:Name="ActionRow" Margin="29,6,29,8">
      <StackPanel Orientation="Horizontal">
        <!-- 主 CTA：绿色实底 + 深色字 + 左侧图标（官网下载按钮三要素） -->
        <Button x:Name="ApplyBtn" Style="{StaticResource Primary}" Width="230">
          <StackPanel Orientation="Horizontal">
            <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF04241B"
                  Width="18" Height="15" Stretch="Uniform" VerticalAlignment="Center" Margin="0,0,9,0"/>
            <TextBlock Text="执行优化" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
        <Button x:Name="RestoreBtn" Content="还原设置" Style="{StaticResource Ghost}" Width="130" Margin="9,0,0,0"/>
        <Button x:Name="RefreshBtn" Content="重新检测" Style="{StaticResource Ghost}" Width="115" Margin="9,0,0,0"/>
        <Button x:Name="GuideBtn" Content="显卡指引" Style="{StaticResource Ghost}" Width="115" Margin="9,0,0,0"/>
      </StackPanel>
      <!-- 执行进度：进度条 + 当前项 + n/m 计数；只在执行期间和结束后可见 -->
      <StackPanel x:Name="ProgressPanel" Visibility="Collapsed" Margin="0,9,0,0">
        <Border x:Name="ProgTrack" Height="6" Background="{StaticResource PanelDeep}"
                BorderBrush="{StaticResource Line}" BorderThickness="1">
          <Border x:Name="ProgFill" Background="{StaticResource Green}" HorizontalAlignment="Left" Width="0"/>
        </Border>
        <Grid Margin="0,5,0,0">
          <TextBlock x:Name="ProgText" Style="{StaticResource Mono}" Foreground="{StaticResource TextSec}"
                     Text="" TextTrimming="CharacterEllipsis" HorizontalAlignment="Left" Margin="0,0,120,0"/>
          <TextBlock x:Name="ProgCount" Style="{StaticResource Mono}" Foreground="{StaticResource Green}"
                     Text="" HorizontalAlignment="Right"/>
        </Grid>
      </StackPanel>
    </StackPanel>

    <StackPanel Grid.Row="4" x:Name="LogRow" Margin="29,0,29,6">
      <Grid Margin="0,0,0,5">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal">
          <TextBlock Text="运行日志" Foreground="{StaticResource TextPri}" FontSize="12"
                     FontWeight="Bold" VerticalAlignment="Center"/>
          <TextBlock Text="RUN LOG" Style="{StaticResource Mono}" FontSize="8" Margin="8,2,0,0"/>
        </StackPanel>
        <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                VerticalAlignment="Center" Margin="12,0,12,0"/>
        <!-- 一键复制：用户反馈问题时直接整段拷日志，不用在小窗里手动拖选。
             图标 Path 用固定坐标（不加 Stretch）：归一化坐标 + Stretch 会被撑大（教训 #3） -->
        <Button x:Name="CopyLogBtn" Grid.Column="2" Style="{StaticResource Ghost}" Height="22"
                FontSize="10" ToolTip="复制全部日志到剪贴板">
          <StackPanel Orientation="Horizontal">
            <Path Data="M 0,3 L 0,11 L 6,11 L 6,3 Z M 3,0 L 9,0 L 9,8 L 6,8" Stroke="#FF00E884"
                  StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center"/>
            <TextBlock x:Name="CopyLogTxt" Text="复制" Margin="5,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
      </Grid>
      <Border Background="{StaticResource LogBg}" BorderBrush="{StaticResource Line}" BorderThickness="1">
        <TextBox x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap" Height="58"
                 VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="Transparent"
                 Foreground="#FF9AA5A0" FontFamily="Consolas" FontSize="11" Padding="9,6"/>
      </Border>
    </StackPanel>

    <!-- 页脚 HUD 线：等宽小字 + 金色短段 + 空心小方块 -->
    <Grid Grid.Row="5" Margin="29,0,29,9" VerticalAlignment="Center">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock Grid.Column="0" Text="DELTA FORCE · BOOSTER" Style="{StaticResource Mono}" FontSize="9"/>
      <Border Grid.Column="1" Width="26" Height="2" Background="{StaticResource Gold}" VerticalAlignment="Center" Margin="9,0,0,0"/>
      <Border Grid.Column="2" Height="1" Background="{StaticResource LineSoft}" VerticalAlignment="Center" Margin="9,0"/>
      <Border Grid.Column="3" Width="5" Height="5" BorderBrush="{StaticResource Green}" BorderThickness="1" VerticalAlignment="Center" Margin="0,0,9,0"/>
      <TextBlock Grid.Column="4" Text="[ V0.12 ] 改动前自动备份 · 可一键还原设置" Style="{StaticResource Mono}" FontSize="9"/>
    </Grid>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
# 不设 Icon 时任务栏/Alt-Tab 显示宿主 powershell.exe 的图标（实机反馈）。
# app.ico 由 build\make-launcher.ps1 生成、随包分发；缺失（手动拷贝的残缺包）时
# 静默跳过——图标问题绝不能挡启动
try {
  $icoPath = Join-Path $PSScriptRoot 'app.ico'
  if (Test-Path -LiteralPath $icoPath) {
    $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri $icoPath))
  }
} catch {}
$ui = @{}
foreach ($n in 'TitleBar','MinBtn','CloseBtn','UpdateBtn','ScanState','HwGrid','GameText','BrowseBtn','CountText',
               'SelAllChk',
               'ItemPanel','RiskyGroup','RiskyPanel','ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','LogBox',
               'PresetBox','SavePresetBtn','DelPresetBtn','PresetNote',
               'TabOptBtn','TabRefBtn','OptPage','RefPage','RefPanel','ActionRow','LogRow',
               'ProgressPanel','ProgTrack','ProgFill','ProgText','ProgCount','CopyLogBtn','CopyLogTxt') {
  $ui[$n] = $window.FindName($n)
}

# ---------- 主题化小部件构造（配色同 XAML：国服官网青绿渐变底 + 正绿 #00E884 + 金标签） ----------

$script:C = @{
  Panel = '#FF0E1B17'; Line = '#FF1B2E28'; LineSoft = '#FF16241F'
  TextPri = '#FFFFFFFF'; TextSec = '#FF9AA5A0'; TextMut = '#FF7A8580'
  Green = '#FF00E884'; GreenDark = '#FF04241B'; Gold = '#FFE5C46A'; GoldDark = '#FF3A2C0C'
  Gray = '#FF7A8580'
}
function New-Brush([string]$Hex) { (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex) }

function New-Text([string]$Content, [string]$Color, [int]$Size, [switch]$Mono) {
  $t = New-Object Windows.Controls.TextBlock
  $t.Text = $Content
  $t.Foreground = New-Brush $Color
  $t.FontSize = $Size
  $t.VerticalAlignment = 'Center'
  if ($Mono) { $t.FontFamily = New-Object Windows.Media.FontFamily 'Consolas' }
  $t
}

function New-HwCard([string]$Label, [string]$Value, [string]$Sub, [switch]$Ribbon) {
  $b = New-Object Windows.Controls.Border
  $b.Background = New-Brush $script:C.Panel
  $b.BorderBrush = New-Brush $script:C.Line
  $b.BorderThickness = New-Object Windows.Thickness 1
  $b.Padding = New-Object Windows.Thickness 10, 6, 10, 6
  $sp = New-Object Windows.Controls.StackPanel
  # 标签行：小空心方块 + 等宽标签（官网信息卡的方形项目符）
  $head = New-Object Windows.Controls.StackPanel
  $head.Orientation = 'Horizontal'
  $sq = New-Object Windows.Controls.Border
  $sq.Width = 5; $sq.Height = 5
  $sq.BorderBrush = New-Brush $script:C.Green
  $sq.BorderThickness = New-Object Windows.Thickness 1
  $sq.VerticalAlignment = 'Center'
  $sq.Margin = New-Object Windows.Thickness 0, 0, 6, 0
  $head.Children.Add($sq) | Out-Null
  $head.Children.Add((New-Text $Label $script:C.TextMut 10 -Mono)) | Out-Null
  $sp.Children.Add($head) | Out-Null
  $v = New-Text $Value $script:C.TextPri 12
  $v.TextTrimming = 'CharacterEllipsis'
  $sp.Children.Add($v) | Out-Null
  $sp.Children.Add((New-Text $Sub $script:C.TextSec 10 -Mono)) | Out-Null
  $b.Child = $sp
  # 官网小卡片右上角的金色三角角标：这里用来标记主力硬件（如主显卡）
  $g = New-Object Windows.Controls.Grid
  $g.Margin = New-Object Windows.Thickness 0, 0, 8, 0
  $g.Children.Add($b) | Out-Null
  if ($Ribbon) {
    $tri = New-Object Windows.Shapes.Path
    $tri.Data = [Windows.Media.Geometry]::Parse('M 0,0 L 12,0 L 12,12 Z')
    $tri.Fill = New-Brush $script:C.Gold
    $tri.HorizontalAlignment = 'Right'
    $tri.VerticalAlignment = 'Top'
    $tri.Margin = New-Object Windows.Thickness 0, 1, 1, 0
    $tri.ToolTip = '游戏使用的主力硬件'
    $g.Children.Add($tri) | Out-Null
  }
  $g
}

function New-Pill([string]$Text, [string]$Fg, [string]$Bg, [string]$Bd) {
  # 官网分类标签手法：实底色块 + 深色粗体字
  $b = New-Object Windows.Controls.Border
  $b.Background = New-Brush $Bg
  $b.BorderBrush = New-Brush $Bd
  $b.BorderThickness = New-Object Windows.Thickness 1
  $b.Padding = New-Object Windows.Thickness 7, 0, 7, 0
  $b.VerticalAlignment = 'Center'
  $t = New-Text $Text $Fg 11
  $t.FontWeight = 'Bold'
  $b.Child = $t
  $b
}

function Update-Count {
  $rows = @($ui.ItemPanel.Children)
  $sel = @($rows | Where-Object { $_.Child.Children[0].IsChecked }).Count
  # 「可执行」= 未处于已就绪/正常态的项（行 Tag 存的是检测到的 Optimized 状态）
  $oper = @($rows | Where-Object { $_.Tag -ne $true })
  $ui.CountText.Text = "已选 $sel / $($rows.Count) · 可执行 $($oper.Count)"
  # 全选框三态回显：程序赋值不触发 Click，不会与点击处理器互相递归
  if ($ui.SelAllChk) {
    $operLeft = @($oper | Where-Object { -not $_.Child.Children[0].IsChecked }).Count
    $ui.SelAllChk.IsChecked = $(if ($sel -eq 0) { $false }
                                elseif ($oper.Count -gt 0 -and $operLeft -eq 0) { $true }
                                else { $null })
  }
}

function New-ItemRow($Item, $State, [bool]$Last) {
  $row = New-Object Windows.Controls.Border
  if (-not $Last) {
    $row.BorderBrush = New-Brush $script:C.LineSoft
    $row.BorderThickness = New-Object Windows.Thickness 0, 0, 0, 1
  }
  $row.Padding = New-Object Windows.Thickness 10, 0, 10, 0
  # 行 Tag 存检测状态：全选框据此只圈「可执行」的项（$true=已就绪，跳过）
  $row.Tag = $State.Optimized

  $g = New-Object Windows.Controls.Grid
  foreach ($w in 'Auto', '*', 'Auto') {
    $c = New-Object Windows.Controls.ColumnDefinition
    $c.Width = [Windows.GridLength]::Auto
    if ($w -eq '*') { $c.Width = New-Object Windows.GridLength 1, 'Star' }
    $g.ColumnDefinitions.Add($c) | Out-Null
  }

  $cb = New-Object Windows.Controls.CheckBox
  $cb.Style = $window.FindResource('TacCheck')
  $cb.Tag = $Item.Id
  $cb.ToolTip = $(if ($Item.Warn) { $Item.Warn } else { $Item.Note })
  # 已优化的项不再默认勾选，避免重复写入撑大备份
  $cb.IsChecked = ($Item.Default -and $State.Optimized -ne $true)
  $nameColor = $(if ($State.Optimized -eq $true) { $script:C.TextSec } else { $script:C.TextPri })
  $cb.Content = New-Text "$($Item.Name)$(if ($Item.Admin) { ' *' })" $nameColor 12
  # 勾选变化时实时刷新计数；手动改动后清掉方案选中态（勾选已不再等于该方案）
  $cb.Add_Click({
    Update-Count
    if (-not $script:ApplyingPreset -and $ui.PresetBox -and $ui.PresetBox.SelectedIndex -ge 0) {
      $ui.PresetBox.SelectedIndex = -1
      $ui.PresetNote.Text = ''
    }
  })
  [Windows.Controls.Grid]::SetColumn($cb, 0)
  $g.Children.Add($cb) | Out-Null

  $detail = New-Text $State.Current $script:C.TextMut 11 -Mono
  $detail.Margin = New-Object Windows.Thickness 12, 0, 12, 0
  $detail.TextTrimming = 'CharacterEllipsis'
  [Windows.Controls.Grid]::SetColumn($detail, 1)
  $g.Children.Add($detail) | Out-Null

  # 状态徽标（官网金色分类标签改造）：就绪=绿实底，待优化=金实底，待定=灰描边。
  # 检测类项目语义不同：发现问题不是「待优化」（工具改不了），用金色「需关注」示警
  $pill = if ($Item.Kind -eq 'check') {
            if ($State.Optimized -eq $true) { New-Pill '正常' $script:C.GreenDark $script:C.Green $script:C.Green }
            elseif ($State.Optimized -eq $false) { New-Pill '需关注' $script:C.GoldDark $script:C.Gold $script:C.Gold }
            else { New-Pill '待定' $script:C.Gray '#00000000' $script:C.Line }
          }
          elseif ($State.Optimized -eq $true) { New-Pill '已就绪' $script:C.GreenDark $script:C.Green $script:C.Green }
          elseif ($State.Optimized -eq $false) { New-Pill '待优化' $script:C.GoldDark $script:C.Gold $script:C.Gold }
          else { New-Pill '待定' $script:C.Gray '#00000000' $script:C.Line }
  $tail = New-Object Windows.Controls.StackPanel
  $tail.Orientation = 'Horizontal'
  # 体检项查出问题时给行内直达入口：不执行优化也能看到教程和下载按钮，
  # 不用等日志（纯文本链接没人会手抄——实机反馈）
  if ($Item.Kind -eq 'check' -and $State.Optimized -eq $false -and $script:CheckHelp.ContainsKey($Item.Id)) {
    $fix = New-Object Windows.Controls.Button
    $fix.Style = $window.FindResource('Ghost')
    $fix.Content = '解决办法'
    $fix.FontSize = 10
    $fix.Height = 20
    $fix.Margin = New-Object Windows.Thickness 0, 0, 8, 0
    $fix.Tag = [pscustomobject]@{ Id = $Item.Id; Name = $Item.Name; Msg = $State.Current }
    # 循环里挂的处理器不能闭包引用循环变量，一律从 sender.Tag 取（与来源链接同一教训）
    $fix.Add_Click({ Show-HealthDialog @($this.Tag) })
    $tail.Children.Add($fix) | Out-Null
  }
  $tail.Children.Add($pill) | Out-Null
  [Windows.Controls.Grid]::SetColumn($tail, 2)
  $g.Children.Add($tail) | Out-Null

  $row.Child = $g
  $row
}

function Update-PresetList {
  # 下拉同时列内置与自存方案；显示名与方案对象按下标一一对应
  $script:PresetList = @(Get-Presets)
  $ui.PresetBox.Items.Clear()
  foreach ($p in $script:PresetList) {
    $ui.PresetBox.Items.Add("$($p.Name)$(if (-not $p.Builtin) { '（自存）' })") | Out-Null
  }
}

function Write-Log([string]$Msg) {
  # 先算好整行再传入：方法括号内的逗号会被当成第二个方法参数，-f 拿不到 $Msg 导致 {1} 越界
  $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $Msg
  $ui.LogBox.AppendText("$line`r`n")
  $ui.LogBox.ScrollToEnd()
}

# ---------- 体检问题的解决办法（教程 + 可点击的官方下载入口） ----------

# 红线：下载链接只能来自这里的硬编码常量，绝不从检测输出/数据文件/网络取——
# 按钮只负责用浏览器打开微软官方地址，本工具自身绝不下载或执行任何安装包
$script:CheckHelp = @{
  'vcredist-check' = @{
    Title = 'VC++ 运行库版本错乱 / 缺失'
    Tutorial = @(
      'VC++ 运行库是游戏底层依赖的微软组件，x64 与 x86 两套必须版本配对。某次安装只更新了其中一套时就会「版本错乱」——这正是 2026 年 7 月底游戏更新后掉帧（300 帧掉到 100）甚至闪退的高发原因。'
      ''
      '修复步骤：'
      '1. 点下方按钮下载 x64 与 x86 两个安装包（微软官方永久链接，浏览器打开）；'
      '2. 依次双击安装——直接覆盖安装即可，不需要先卸载旧版本；'
      '3. 装完重启电脑；'
      '4. 回到本工具点「重新检测」，确认此项变成「正常」。'
    ) -join "`n"
    Links = @(
      @{ Text = '下载 x64 运行库'; Url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe' }
      @{ Text = '下载 x86 运行库'; Url = 'https://aka.ms/vs/17/release/vc_redist.x86.exe' }
    )
  }
  'xmp-check' = @{
    Title = '内存 XMP/EXPO 未开启'
    Tutorial = @(
      'XMP（Intel 平台叫法）/ EXPO 或 DOCP（AMD 平台叫法）是内存条出厂标定的高频档位。不开启时内存跑在保守的 JEDEC 基准频率上，等于放着买好的频率不用；开启后帧数一般会有提升，幅度因 CPU/内存/游戏而异，无法承诺具体数字。'
      ''
      '开启步骤（BIOS 设置只能手动进，任何软件都改不了）：'
      '1. 重启电脑，开机自检画面出现时反复按 Del 或 F2 进入 BIOS（部分品牌是 F1/F10）；'
      '2. 找到内存/超频页面：Intel 主板找 XMP，AMD 主板找 EXPO 或 DOCP，选档位 1 开启；'
      '3. 按 F10 保存并退出；'
      '4. 万一开启后开不了机：多数主板会自动回退重启；不行就再进 BIOS 恢复默认设置（Load Optimized Defaults），恢复后与改动前完全一致，不会造成损坏。'
    ) -join "`n"
    Links = @()
  }
}

# 打开外部链接的唯一出口：只放行 http/https 网页地址（与更新入口同一条红线）
function Open-HelpLink([string]$Url) {
  if ($Url -match '^https?://') { Start-Process $Url } else { Write-Log "已拦截非网页链接：$Url" }
}

# 「体检发现问题」对话框：日志里的纯文本链接等于没给（实机反馈用户不会手抄网址），
# 这里逐条列问题 + 逐步教程 + 可点击的下载按钮。构建与弹出拆开便于离屏渲染验证
function Build-HealthDialog($AttResults) {
  $hxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="500" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="体检发现问题" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="HEALTH CHECK" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <TextBlock Text="以下问题本工具改不了，但按教程手动处理并不难：" Foreground="#FF9AA5A0"
               FontSize="12" Margin="14,12,14,0"/>
    <ScrollViewer MaxHeight="430" VerticalScrollBarVisibility="Auto" Margin="14,10,14,12">
      <StackPanel x:Name="ListPanel"/>
    </ScrollViewer>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" IsCancel="True"
              Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="知道了"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  $dlg = [Windows.Markup.XamlReader]::Parse($hxaml)
  $panel = $dlg.FindName('ListPanel')
  foreach ($r in @($AttResults)) {
    $help = $script:CheckHelp["$($r.Id)"]
    $card = New-Object Windows.Controls.Border
    $card.Background = New-Brush $script:C.Panel
    $card.BorderBrush = New-Brush $script:C.Line
    $card.BorderThickness = New-Object Windows.Thickness 1
    $card.Padding = New-Object Windows.Thickness 12, 9, 12, 10
    $card.Margin = New-Object Windows.Thickness 0, 0, 0, 8
    $csp = New-Object Windows.Controls.StackPanel
    $tt = New-Text "$(if ($help -and $help.Title) { $help.Title } else { $r.Name })" $script:C.Gold 13
    $tt.FontWeight = 'Bold'
    $csp.Children.Add($tt) | Out-Null
    $ms = New-WrapText "检测结果：$($r.Msg)" $script:C.TextSec 11
    $ms.Margin = New-Object Windows.Thickness 0, 5, 0, 0
    $csp.Children.Add($ms) | Out-Null
    if ($help -and $help.Tutorial) {
      $tu = New-WrapText $help.Tutorial $script:C.TextMut 11
      $tu.LineHeight = 18
      $tu.Margin = New-Object Windows.Thickness 0, 7, 0, 0
      $csp.Children.Add($tu) | Out-Null
    }
    if ($help -and @($help.Links).Count -gt 0) {
      $lr = New-Object Windows.Controls.StackPanel
      $lr.Orientation = 'Horizontal'
      $lr.Margin = New-Object Windows.Thickness 0, 9, 0, 0
      foreach ($lk in @($help.Links)) {
        $lb = New-Object Windows.Controls.Button
        $lb.Style = $window.FindResource('Ghost')
        $lb.Content = "$($lk.Text)"
        $lb.FontSize = 11
        $lb.Height = 26
        $lb.Margin = New-Object Windows.Thickness 0, 0, 8, 0
        $lb.Tag = "$($lk.Url)"
        $lb.Add_Click({ Open-HelpLink "$($this.Tag)" })
        $lr.Children.Add($lb) | Out-Null
      }
      $csp.Children.Add($lr) | Out-Null
    }
    $card.Child = $csp
    $panel.Children.Add($card) | Out-Null
  }
  $dlg
}

function Show-HealthDialog($AttResults) {
  # 事件处理器在模态期间回调，与其他对话框同理：对象放 script 作用域最稳
  $script:HcDlg = Build-HealthDialog $AttResults
  $script:HcDlg.Owner = $window
  $script:HcDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:HcDlg.DragMove() })
  $script:HcDlg.FindName('OkBtn').Add_Click({ $script:HcDlg.DialogResult = $true })
  [void]$script:HcDlg.ShowDialog()
}

# ---------- 主播设置参考页（纯展示，数据来自 data\streamer-settings.json） ----------

$script:DataFile = Join-Path $script:RootDir 'data\streamer-settings.json'

function New-WrapText([string]$Content, [string]$Color, [int]$Size) {
  $t = New-Text $Content $Color $Size
  $t.TextWrapping = 'Wrap'
  $t
}

function New-RefCell([Windows.Controls.Grid]$Table, [int]$Row, [int]$Col, $Child, [bool]$Header) {
  $b = New-Object Windows.Controls.Border
  $b.BorderBrush = New-Brush $script:C.LineSoft
  $b.BorderThickness = New-Object Windows.Thickness 0, 0, 1, 1
  $b.Padding = New-Object Windows.Thickness 10, 5, 10, 5
  if ($Header) { $b.Background = New-Brush '#FF0B1713' }
  $b.Child = $Child
  [Windows.Controls.Grid]::SetRow($b, $Row)
  [Windows.Controls.Grid]::SetColumn($b, $Col)
  $Table.Children.Add($b) | Out-Null
}

function Add-RefNotice([string]$Title, [string]$Detail) {
  # 数据缺失/损坏时的降级提示：本页是参考内容，任何情况下都不该抛错打断界面
  $b = New-Object Windows.Controls.Border
  $b.Background = New-Brush $script:C.Panel
  $b.BorderBrush = New-Brush $script:C.Line
  $b.BorderThickness = New-Object Windows.Thickness 1
  $b.Padding = New-Object Windows.Thickness 16, 14, 16, 14
  $b.Margin = New-Object Windows.Thickness 0, 8, 0, 0
  $sp = New-Object Windows.Controls.StackPanel
  $t = New-Text $Title $script:C.TextPri 13
  $t.FontWeight = 'Bold'
  $sp.Children.Add($t) | Out-Null
  $d = New-WrapText $Detail $script:C.TextSec 11
  $d.Margin = New-Object Windows.Thickness 0, 6, 0, 0
  $sp.Children.Add($d) | Out-Null
  $b.Child = $sp
  $ui.RefPanel.Children.Add($b) | Out-Null
}

function Update-StreamerPage {
  $ui.RefPanel.Children.Clear()

  # 免责声明放最上面：必须让用户第一眼知道这页只是参考、工具改不了游戏内设置
  $warn = New-Object Windows.Controls.Border
  $warn.Background = New-Brush '#FF2A2008'
  $warn.BorderBrush = New-Brush $script:C.Gold
  $warn.BorderThickness = New-Object Windows.Thickness 1
  $warn.Padding = New-Object Windows.Thickness 12, 8, 12, 8
  $wsp = New-Object Windows.Controls.StackPanel
  $wt = New-Text '仅供参考 · 本工具不会也无法修改游戏内设置' $script:C.Gold 12
  $wt.FontWeight = 'Bold'
  $wsp.Children.Add($wt) | Out-Null
  $wd = New-WrapText '下表是头部主播公开的游戏内画质设置记录，请进入游戏后在「设置 → 画面」里手动对照调整。主播设置随游戏版本和硬件不同而变化，不保证适合你的机器。' $script:C.TextSec 11
  $wd.Margin = New-Object Windows.Thickness 0, 4, 0, 0
  $wsp.Children.Add($wd) | Out-Null
  $warn.Child = $wsp
  $ui.RefPanel.Children.Add($warn) | Out-Null

  if (-not (Test-Path -LiteralPath $script:DataFile)) {
    Add-RefNotice '数据尚未就绪' '主播画面设置数据（data\streamer-settings.json）还没有生成。数据到位后切回本页会自动加载。'
    return
  }
  $data = $null
  try { $data = Get-Content -LiteralPath $script:DataFile -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { Add-RefNotice '数据读取失败' "streamer-settings.json 暂时无法解析（可能正在生成中）：$($_.Exception.Message)"; return }

  $streamers = @($data.streamers | Where-Object { $_ })
  if ($streamers.Count -eq 0) { Add-RefNotice '数据尚未就绪' '数据文件里还没有主播条目。'; return }

  # 行头顺序优先用数据声明的 settings_schema。v0.12 起 schema 项支持 { name, group }
  # 对象——group 即游戏内「设置 → 画面」的菜单分组；老格式的纯字符串仍能读，
  # 缺 group 的一律归入「其他」，数据文件与界面可以各自先后升级互不拖累
  $schema = @()
  foreach ($it in @($data.settings_schema | Where-Object { $_ })) {
    if ($it -is [string]) {
      if ("$it" -ne '') { $schema += [pscustomobject]@{ Name = "$it"; Group = '' } }
    } elseif ("$($it.name)" -ne '') {
      $schema += [pscustomobject]@{ Name = "$($it.name)"; Group = "$($it.group)" }
    }
  }
  if ($schema.Count -eq 0) {
    # 数据没声明行头：按各主播设置键的出现顺序取并集
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($s in $streamers) {
      if ($s.settings) {
        foreach ($p in $s.settings.PSObject.Properties) {
          if (-not $seen.Contains($p.Name)) { [void]$seen.Add($p.Name) }
        }
      }
    }
    $schema = @($seen | ForEach-Object { [pscustomobject]@{ Name = $_; Group = '' } })
  }

  # 分组顺序按 schema 首次出现的顺序；「其他」是兜底组不是游戏菜单，永远排最后
  $groupNames = New-Object System.Collections.Generic.List[string]
  foreach ($col in $schema) {
    $g = $(if ("$($col.Group)" -ne '') { "$($col.Group)" } else { '其他' })
    if (-not $groupNames.Contains($g)) { [void]$groupNames.Add($g) }
  }
  if ($groupNames.Contains('其他')) { [void]$groupNames.Remove('其他'); [void]$groupNames.Add('其他') }

  $meta = New-Text "数据更新：$(if ($data.updated) { $data.updated } else { '未知' })$(if ($data.note) { "　·　$($data.note)" })" $script:C.TextMut 10 -Mono
  $meta.Margin = New-Object Windows.Thickness 2, 8, 0, 8
  $meta.TextWrapping = 'Wrap'
  $ui.RefPanel.Children.Add($meta) | Out-Null

  # 分组依据要如实交代（含「位置可能随版本变化」）：优先用数据文件里的 schema_note，
  # 老数据没有分组信息时提示这是兜底展示
  $srcNote = $(if ($data.schema_note) { "$($data.schema_note)" }
               elseif (@($schema | Where-Object { "$($_.Group)" -ne '' }).Count -eq 0) {
                 '当前数据文件未带菜单分组信息，设置项暂归入「其他」统一展示。' })
  if ($srcNote) {
    $sn = New-WrapText $srcNote $script:C.TextMut 10
    $sn.Margin = New-Object Windows.Thickness 2, 0, 0, 8
    $ui.RefPanel.Children.Add($sn) | Out-Null
  }

  if ($schema.Count -gt 0) {
    # 对照表：行=设置项、列=主播，按游戏内菜单分组插入组标题行（实机反馈：扁平大表
    # 拿进游戏找不到每项在哪个菜单下）。单一 Grid 保证各组列宽对齐、横向滚动只有一条
    $tbl = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition
    $c0.Width = [Windows.GridLength]::Auto
    $tbl.ColumnDefinitions.Add($c0) | Out-Null
    foreach ($s in $streamers) {
      $c = New-Object Windows.Controls.ColumnDefinition
      $c.Width = [Windows.GridLength]::Auto
      $c.MinWidth = 110
      $tbl.ColumnDefinitions.Add($c) | Out-Null
    }
    $totalRows = 1 + $groupNames.Count + $schema.Count
    for ($r = 0; $r -lt $totalRows; $r++) {
      $rd = New-Object Windows.Controls.RowDefinition
      $rd.Height = [Windows.GridLength]::Auto
      $tbl.RowDefinitions.Add($rd) | Out-Null
    }
    New-RefCell $tbl 0 0 (New-Text '设置项' $script:C.TextMut 11 -Mono) $true
    for ($j = 0; $j -lt $streamers.Count; $j++) {
      $s = $streamers[$j]
      $hs = New-Object Windows.Controls.StackPanel
      $nm = New-Text "$(if ($s.name) { $s.name } else { "主播$($j + 1)" })" $script:C.Green 12
      $nm.FontWeight = 'Bold'
      $hs.Children.Add($nm) | Out-Null
      if ($s.platform) { $hs.Children.Add((New-Text "$($s.platform)" $script:C.TextMut 10 -Mono)) | Out-Null }
      New-RefCell $tbl 0 ($j + 1) $hs $true
    }
    $rowIdx = 1
    foreach ($gName in $groupNames) {
      $inGroup = @($schema | Where-Object { $(if ("$($_.Group)" -ne '') { "$($_.Group)" } else { '其他' }) -eq $gName })
      if ($inGroup.Count -eq 0) { continue }
      # 组标题行：金色分类标签横贯整行（官网 chip 手法），提示进游戏后翻哪个菜单
      $gb = New-Object Windows.Controls.Border
      $gb.Background = New-Brush '#FF10201A'
      $gb.BorderBrush = New-Brush $script:C.LineSoft
      $gb.BorderThickness = New-Object Windows.Thickness 0, 0, 1, 1
      $gb.Padding = New-Object Windows.Thickness 10, 5, 10, 5
      $gsp = New-Object Windows.Controls.StackPanel
      $gsp.Orientation = 'Horizontal'
      $gsp.Children.Add((New-Pill $gName $script:C.GoldDark $script:C.Gold $script:C.Gold)) | Out-Null
      $gh = New-Text $(if ($gName -eq '其他') { '未归入游戏菜单的项' } else { "游戏内「设置 → 画面 → $gName」" }) $script:C.TextMut 10 -Mono
      $gh.Margin = New-Object Windows.Thickness 9, 0, 0, 0
      $gsp.Children.Add($gh) | Out-Null
      $gb.Child = $gsp
      [Windows.Controls.Grid]::SetRow($gb, $rowIdx)
      [Windows.Controls.Grid]::SetColumn($gb, 0)
      [Windows.Controls.Grid]::SetColumnSpan($gb, $streamers.Count + 1)
      $tbl.Children.Add($gb) | Out-Null
      $rowIdx++
      foreach ($col in $inGroup) {
        $key = "$($col.Name)"
        New-RefCell $tbl $rowIdx 0 (New-Text $key $script:C.TextSec 11) $false
        for ($j = 0; $j -lt $streamers.Count; $j++) {
          $s = $streamers[$j]
          $v = $null
          if ($s.settings) {
            $p = $s.settings.PSObject.Properties[$key]
            if ($p -and "$($p.Value)" -ne '') { $v = "$($p.Value)" }
          }
          $cell = New-Text $(if ($v) { $v } else { '—' }) $(if ($v) { $script:C.TextPri } else { $script:C.TextMut }) 11
          New-RefCell $tbl $rowIdx ($j + 1) $cell $false
        }
        $rowIdx++
      }
    }
    $tblWrap = New-Object Windows.Controls.Border
    $tblWrap.BorderBrush = New-Brush $script:C.Line
    $tblWrap.BorderThickness = New-Object Windows.Thickness 1, 1, 0, 0
    $tblWrap.HorizontalAlignment = 'Left'
    $tblWrap.Child = $tbl
    $hsv = New-Object Windows.Controls.ScrollViewer
    $hsv.HorizontalScrollBarVisibility = 'Auto'
    $hsv.VerticalScrollBarVisibility = 'Disabled'
    $hsv.Content = $tblWrap
    # 滚轮失灵的根因在这：ScrollViewer 的类处理器无条件把 MouseWheel 标记成已处理，
    # 哪怕纵向滚动被 Disabled 也不放行，事件到不了外层页面 ScrollViewer；对照表又占满
    # 首屏，于是整页滚轮像坏了一样。纵向滚轮对这个横向表没有任何用处，改成拦下原事件、
    # 以父容器为起点重新冒泡，让外层页面 ScrollViewer 接管
    $hsv.Add_PreviewMouseWheel({
      param($s, $e)
      if ($e.Handled) { return }
      $e.Handled = $true
      $fwd = New-Object Windows.Input.MouseWheelEventArgs($e.MouseDevice, $e.Timestamp, $e.Delta)
      $fwd.RoutedEvent = [Windows.UIElement]::MouseWheelEvent
      $fwd.Source = $s
      $parent = [Windows.Media.VisualTreeHelper]::GetParent($s)
      if ($parent) { $parent.RaiseEvent($fwd) }
    })
    $ui.RefPanel.Children.Add($hsv) | Out-Null
  }

  # 来源与硬件卡片：每位主播一张，来源链接只放行 http/https（与更新入口同一条红线）
  foreach ($s in $streamers) {
    $card = New-Object Windows.Controls.Border
    $card.Background = New-Brush $script:C.Panel
    $card.BorderBrush = New-Brush $script:C.Line
    $card.BorderThickness = New-Object Windows.Thickness 1
    $card.Padding = New-Object Windows.Thickness 12, 8, 12, 8
    $card.Margin = New-Object Windows.Thickness 0, 8, 0, 0
    $csp = New-Object Windows.Controls.StackPanel
    $head = New-Object Windows.Controls.StackPanel
    $head.Orientation = 'Horizontal'
    $nm2 = New-Text "$(if ($s.name) { $s.name } else { '未命名主播' })" $script:C.TextPri 12
    $nm2.FontWeight = 'Bold'
    $head.Children.Add($nm2) | Out-Null
    if ($s.platform) {
      $plat = New-Text "$($s.platform)" $script:C.TextMut 10 -Mono
      $plat.Margin = New-Object Windows.Thickness 8, 0, 0, 0
      $head.Children.Add($plat) | Out-Null
    }
    if ("$($s.url)" -match '^https?://') {
      $lnk = New-Object Windows.Controls.Button
      $lnk.Style = $window.FindResource('Ghost')
      $lnk.Content = '查看来源'
      $lnk.FontSize = 10
      $lnk.Height = 20
      $lnk.Margin = New-Object Windows.Thickness 10, 0, 0, 0
      $lnk.Tag = "$($s.url)"
      # 循环里挂的处理器不能直接引用 $s（点击时 $s 早已是最后一个元素），从 sender.Tag 取
      $lnk.Add_Click({ $u = "$($this.Tag)"; if ($u -match '^https?://') { Start-Process $u } })
      $head.Children.Add($lnk) | Out-Null
    }
    $csp.Children.Add($head) | Out-Null
    $hw2 = New-WrapText "硬件：$(if ($s.hardware) { $s.hardware } else { '未注明' })$(if ($s.captured) { "　·　记录于 $($s.captured)" })" $script:C.TextSec 11
    $hw2.Margin = New-Object Windows.Thickness 0, 4, 0, 0
    $csp.Children.Add($hw2) | Out-Null
    if ($s.notes) {
      $nt = New-WrapText "备注：$($s.notes)" $script:C.TextMut 10
      $nt.Margin = New-Object Windows.Thickness 0, 3, 0, 0
      $csp.Children.Add($nt) | Out-Null
    }
    $tail = New-Text '设置随版本/硬件而异，仅供参考' $script:C.Gold 10
    $tail.Margin = New-Object Windows.Thickness 0, 4, 0, 0
    $csp.Children.Add($tail) | Out-Null
    $card.Child = $csp
    $ui.RefPanel.Children.Add($card) | Out-Null
  }
}

# ---------- 标签页切换与执行态 ----------

$script:Busy = $false

function Select-Tab([string]$Which) {
  $opt = ($Which -eq 'opt')
  $ui.TabOptBtn.Tag = $(if ($opt) { 'on' } else { '' })
  $ui.TabRefBtn.Tag = $(if ($opt) { '' } else { 'on' })
  $ui.OptPage.Visibility = $(if ($opt) { 'Visible' } else { 'Collapsed' })
  $ui.RefPage.Visibility = $(if ($opt) { 'Collapsed' } else { 'Visible' })
  # 执行按钮和日志只属于优化页，参考页收起以免让人误以为参考设置能「执行」
  $ui.ActionRow.Visibility = $(if ($opt) { 'Visible' } else { 'Collapsed' })
  $ui.LogRow.Visibility = $(if ($opt) { 'Visible' } else { 'Collapsed' })
  # 每次切入都重建：数据文件可能是界面启动之后才生成的
  if (-not $opt) { Update-StreamerPage }
}

function Set-BusyState([bool]$On) {
  # 执行期间禁用一切入口防重复点击；窗口关闭在 CloseBtn 处单独拦截
  $script:Busy = $On
  foreach ($n in 'ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','BrowseBtn',
                 'SavePresetBtn','DelPresetBtn','PresetBox','TabOptBtn','TabRefBtn','UpdateBtn') {
    if ($ui[$n]) { $ui[$n].IsEnabled = -not $On }
  }
}

function Update-ApplyProgress($p) {
  # 引擎每处理一项回调两次：start 刷「正在处理」，done 落一条实时日志并推进进度条
  if ($p.Stage -eq 'start') {
    $ui.ProgText.Text = "正在处理：$($p.Name)"
    $ui.ProgCount.Text = "第 $($p.Index) / 共 $($p.Total) 项"
  } else {
    $r = $p.Result
    # 检测项发现问题挂 Attention：是「体检查出了东西」不是「工具失败了」，标签要分开
    $tag = $(if ($r.Attention) { '[提示]' } elseif ($r.Ok) { '[成功]' } elseif ($r.Skipped) { '[跳过]' } else { '[失败]' })
    Write-Log "$tag $($r.Name) — $($r.Msg)"
    $w = $ui.ProgTrack.ActualWidth - 2
    if ($w -gt 0 -and $p.Total -gt 0) { $ui.ProgFill.Width = [math]::Max(0, $w * $p.Index / $p.Total) }
  }
  # 单线程模型：手动泵一次渲染队列让进度立即上屏。用 Render 优先级不放行输入事件，
  # 执行期间的点击一律进不来（按钮禁用之外的第二道保险），界面也不会整体假死
  $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
}

function Update-RestoreProgress($p) {
  # 还原复用执行优化的进度面板；粒度是备份里的「值」而不是优化项，单条极快且可能有
  # 几十条，逐条落日志会刷爆日志框——只推进度条和当前项文案，失败明细由汇总统一给
  if ($p.Stage -eq 'start') {
    $ui.ProgText.Text = "正在还原：$($p.Name)"
    $ui.ProgCount.Text = "第 $($p.Index) / 共 $($p.Total) 项"
  } else {
    $w = $ui.ProgTrack.ActualWidth - 2
    if ($w -gt 0 -and $p.Total -gt 0) { $ui.ProgFill.Width = [math]::Max(0, $w * $p.Index / $p.Total) }
  }
  $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
}

# 主题化确认/信息对话框：原生 MessageBox 白底系统样式与深色主题完全不搭（用户实测吐槽），
# 全站确认（执行/还原/删除）和长文本指引统一走这里。正文放 ScrollViewer：
# 执行清单可达 30 行、显卡指引更长，超高时内部滚动而不是把对话框撑出屏幕
function Show-ConfirmDialog([string]$ChipText, [string]$EnText, [string]$Message,
                            [string]$OkText = '确定', [switch]$InfoOnly, [string]$Banner) {
  $cxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="440" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock x:Name="ChipTxt" Text="" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock x:Name="EnTxt" Text="" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <!-- 醒目横幅（可选）：显卡指引用它标出「检测到你的显卡：xxx」，让用户一眼确认
         这份指引就是按自己的硬件生成的（实机反馈感知不到） -->
    <Border x:Name="BannerRow" Visibility="Collapsed" Background="#FF0E2A21" BorderBrush="#FF17603F"
            BorderThickness="1" Margin="14,12,14,0" Padding="10,7">
      <TextBlock x:Name="BannerTxt" Text="" Foreground="#FF00E884" FontSize="12" FontWeight="Bold"
                 TextWrapping="Wrap"/>
    </Border>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,12,14,12">
      <ScrollViewer MaxHeight="340" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="MsgTxt" Text="" Foreground="#FF9AA5A0" FontSize="12" LineHeight="19"
                   TextWrapping="Wrap" Padding="12,9"/>
      </ScrollViewer>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="OkTxt" Text="确定"/>
      </Button>
      <Button x:Name="CancelBtn" Width="80" Height="30" IsCancel="True" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="取消"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  # 事件处理器在模态期间回调，与 Show-UpdateDialog 同理：要用的对象放 script 作用域最稳
  $script:CfmDlg = [Windows.Markup.XamlReader]::Parse($cxaml)
  $script:CfmDlg.Owner = $window
  $script:CfmDlg.FindName('ChipTxt').Text = $ChipText
  $script:CfmDlg.FindName('EnTxt').Text = $EnText
  $script:CfmDlg.FindName('MsgTxt').Text = $Message
  $script:CfmDlg.FindName('OkTxt').Text = $OkText
  # 信息模式（如显卡指引）没有「取消」的语义，只留一个确认按钮
  if ($InfoOnly) { $script:CfmDlg.FindName('CancelBtn').Visibility = 'Collapsed' }
  # 可选醒目横幅：显卡指引用它标出检测到的显卡型号
  if ($Banner) {
    $script:CfmDlg.FindName('BannerTxt').Text = $Banner
    $script:CfmDlg.FindName('BannerRow').Visibility = 'Visible'
  }
  $script:CfmDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:CfmDlg.DragMove() })
  $script:CfmDlg.FindName('OkBtn').Add_Click({ $script:CfmDlg.DialogResult = $true })
  $script:CfmDlg.FindName('CancelBtn').Add_Click({ $script:CfmDlg.DialogResult = $false })
  [bool]$script:CfmDlg.ShowDialog()
}

# 重启调用单独包一层：验证脚本可整体替换成 mock 走完整个交互链路，
# 保证任何测试都不会真的把机器重启掉
function Invoke-SystemReboot {
  Start-Process shutdown.exe -ArgumentList '/r', '/t', '5'
}

# 执行完成后的醒目重启提醒：此前只在日志末尾一行小字，用户根本注意不到（实机反馈）。
# 只在「本次成功项里确实有需重启的」才弹；纯检测/即时生效项不触发。
# 返回 $true 表示用户点了「立即重启」——调用方还要再走一道确认，重启是破坏性动作
function Show-RebootDialog([string[]]$ItemNames) {
  $rxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="460" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,16">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="重启提醒" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="REBOOT REQUIRED" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <StackPanel Orientation="Horizontal" Margin="16,14,16,4">
      <!-- 电源符号图标：圆环开口 + 竖杠，全部固定尺寸拼装，不用归一化 Path（教训 #3） -->
      <Grid Width="34" Height="34" VerticalAlignment="Center">
        <Ellipse Stroke="#FF00E884" StrokeThickness="2.5" Margin="3,6,3,2"/>
        <Border Width="8" Height="14" Background="#FF0C1814" VerticalAlignment="Top" HorizontalAlignment="Center"/>
        <Border Width="3" Height="15" Background="#FF00E884" VerticalAlignment="Top" HorizontalAlignment="Center" Margin="0,1,0,0"/>
      </Grid>
      <StackPanel Margin="13,0,0,0" VerticalAlignment="Center">
        <TextBlock Text="需要重启电脑" Foreground="#FFFFFFFF" FontSize="16" FontWeight="Bold"/>
        <TextBlock Text="以下优化项已写入成功，但要等重启后才完全生效：" Foreground="#FF9AA5A0"
                   FontSize="11" Margin="0,3,0,0"/>
      </StackPanel>
    </StackPanel>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="16,8,16,12">
      <ScrollViewer MaxHeight="180" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="ItemsTxt" Text="" Foreground="#FF9AA5A0" FontSize="12" LineHeight="20"
                   TextWrapping="Wrap" Padding="12,8"/>
      </ScrollViewer>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="16,0,16,0">
      <Button x:Name="RebootBtn" MinWidth="110" Height="32" Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="立即重启"/>
      </Button>
      <Button x:Name="LaterBtn" MinWidth="110" Height="32" IsCancel="True" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="稍后自己重启"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  # 事件处理器在模态期间回调，与其他对话框同理：要用的对象放 script 作用域最稳
  $script:RbDlg = [Windows.Markup.XamlReader]::Parse($rxaml)
  $script:RbDlg.Owner = $window
  $script:RbDlg.FindName('ItemsTxt').Text = (@($ItemNames | ForEach-Object { "· $_" }) -join "`n")
  $script:RbDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:RbDlg.DragMove() })
  $script:RbDlg.FindName('RebootBtn').Add_Click({ $script:RbDlg.DialogResult = $true })
  $script:RbDlg.FindName('LaterBtn').Add_Click({ $script:RbDlg.DialogResult = $false })
  [bool]$script:RbDlg.ShowDialog()
}

# 贴合主题的输入对话框：项目禁用原生 InputBox 风格弹窗
function Show-NameDialog {
  $dxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="380" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="存为方案" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="SAVE PRESET" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <TextBlock Text="把当前勾选的优化项保存为方案，输入方案名：" Foreground="#FF9AA5A0" Margin="14,12,14,8"/>
    <Border Background="#FF0B1712" BorderBrush="#FF2C443B" BorderThickness="1" Margin="14,0,14,12">
      <TextBox x:Name="NameBox" BorderThickness="0" Background="Transparent" Foreground="#FFFFFFFF"
               CaretBrush="#FF00E884" Padding="9,6" FontSize="12" MaxLength="40"/>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" Width="96" Height="30" IsDefault="True" Foreground="#FF04241B"
              FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="确定"/>
      </Button>
      <Button x:Name="CancelBtn" Width="80" Height="30" IsCancel="True" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="取消"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  $dlg = [Windows.Markup.XamlReader]::Parse($dxaml)
  $dlg.Owner = $window
  $nameBox = $dlg.FindName('NameBox')
  $dlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $dlg.DragMove() })
  $dlg.FindName('OkBtn').Add_Click({ $dlg.DialogResult = $true })
  $dlg.FindName('CancelBtn').Add_Click({ $dlg.DialogResult = $false })
  $dlg.Add_ContentRendered({ $nameBox.Focus() | Out-Null })
  if ($dlg.ShowDialog()) {
    $txt = "$($nameBox.Text)".Trim()
    if ($txt) { return $txt }
  }
  $null
}

# 更新对话框的按钮态复位：取消下载 / 下载失败后回到可再次操作的状态。
# 「立即更新」只在清单过了安检（CanInline）时出现，降级入口「前往下载」永远可用。
function Reset-UpdDialogButtons {
  $script:UpdUi.DlPanel.Visibility = 'Collapsed'
  $script:UpdUi.CancelDlBtn.Visibility = 'Collapsed'
  $script:UpdUi.SkipChk.Visibility = 'Visible'
  $script:UpdUi.UpdBtn.Visibility = $(if ($script:UpdDlgInfo.CanInline) { 'Visible' } else { 'Collapsed' })
  $script:UpdUi.GoBtn.Visibility = 'Visible'
  $script:UpdUi.LaterBtn.Visibility = 'Visible'
}

# 更新提醒对话框：v0.11 起支持内置更新——「立即更新」在应用内下载安装包（进度条 +
# 可取消），完成后强制 SHA256/大小校验，通过才提示关闭本程序并启动安装器；
# 下载源限白名单 https（见 scripts\updater.ps1），清单缺校验信息或任一环节失败都
# 退回「浏览器打开下载页」的旧行为。下载/安装永远由用户点击触发，检查只负责提醒。
function Show-UpdateDialog($UpdInfo) {
  $uxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="470" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="发现新版本" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="UPDATE AVAILABLE" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <StackPanel Orientation="Horizontal" Margin="14,12,14,4">
      <TextBlock x:Name="VerText" Text="" Foreground="#FF00E884" FontSize="15" FontWeight="Bold"/>
      <TextBlock x:Name="CurText" Text="" Foreground="#FF7A8580" FontSize="11" Margin="9,0,0,0"
                 VerticalAlignment="Bottom"/>
    </StackPanel>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,6,14,8">
      <ScrollViewer MaxHeight="140" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="NotesText" Text="" Foreground="#FF9AA5A0" FontSize="11"
                   TextWrapping="Wrap" Padding="10,8"/>
      </ScrollViewer>
    </Border>
    <!-- 内置更新说明：绿色版没有独立更新通道，也走安装器（覆盖安装保护会保住配置与备份） -->
    <TextBlock x:Name="InlineNote" Text="" Foreground="#FF7A8580" FontSize="10"
               TextWrapping="Wrap" Margin="14,0,14,8"/>
    <!-- 下载进度区：点「立即更新」后展开；进度由轮询定时器在 UI 线程刷新 -->
    <StackPanel x:Name="DlPanel" Visibility="Collapsed" Margin="14,0,14,10">
      <Grid>
        <TextBlock x:Name="DlPhaseText" Text="正在下载更新…" Foreground="#FF9AA5A0" FontSize="11"/>
        <TextBlock x:Name="DlSizeText" Text="" Foreground="#FF7A8580" FontFamily="Consolas"
                   FontSize="10" HorizontalAlignment="Right" VerticalAlignment="Center"/>
      </Grid>
      <Border x:Name="DlTrack" Height="8" Background="#FF081310" BorderBrush="#FF1B2E28"
              BorderThickness="1" Margin="0,6,0,0">
        <Border x:Name="DlFill" Background="#FF00E884" HorizontalAlignment="Left" Width="0"/>
      </Border>
    </StackPanel>
    <!-- 失败区：下载/校验失败的明确报错，旁边的「前往下载」变身降级入口 -->
    <Border x:Name="ErrPanel" Visibility="Collapsed" Background="#FF1A0E10" BorderBrush="#FF7A3034"
            BorderThickness="1" Margin="14,0,14,10">
      <TextBlock x:Name="ErrText" Text="" Foreground="#FFE5484D" FontSize="11"
                 TextWrapping="Wrap" Padding="10,7"/>
    </Border>
    <Grid Margin="14,0,14,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <CheckBox x:Name="SkipChk" Grid.Column="0" VerticalAlignment="Center">
        <CheckBox.Template>
          <ControlTemplate TargetType="CheckBox">
            <Border Background="Transparent" Padding="0,3">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="Box" Width="13" Height="13" BorderBrush="#FF2C443B"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Center">
                  <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="#FF04241B"
                        StrokeThickness="2" Visibility="Collapsed"/>
                </Border>
                <TextBlock Text="不再提醒此版本" Foreground="#FF7A8580" FontSize="11"
                           Margin="7,0,0,0" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="#FF00E884"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </CheckBox.Template>
      </CheckBox>
      <Button x:Name="UpdBtn" Grid.Column="1" MinWidth="96" Height="30" Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="立即更新"/>
      </Button>
      <Button x:Name="GoBtn" Grid.Column="2" MinWidth="96" Height="30" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="GoTxt" Text="前往下载"/>
      </Button>
      <Button x:Name="CancelDlBtn" Grid.Column="3" Visibility="Collapsed" MinWidth="96" Height="30"
              Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="#FF7A8580"/>
                <Setter TargetName="B" Property="BorderBrush" Value="#FF1B2E28"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="CancelDlTxt" Text="取消下载"/>
      </Button>
      <Button x:Name="LaterBtn" Grid.Column="4" Width="86" Height="30" IsCancel="True"
              Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="稍后再说"/>
      </Button>
    </Grid>
  </StackPanel>
</Window>
'@
  # 上一次对话框可能留有未收尾的下载：先请求取消并回收，避免两套轮询同时操作控件
  if ($script:DlPollTimer) { $script:DlPollTimer.Stop() }
  if ($script:DlState -and -not $script:DlState.Done) { $script:DlState.Cancel = $true }
  if ($script:DlJob) { try { $script:DlJob.Dispose() } catch {}; $script:DlJob = $null }
  $script:DlState = $null

  # 事件处理器在模态期间回调，跟 Show-NameDialog 一样把要用的对象放 script 作用域最稳
  $script:UpdDlg = [Windows.Markup.XamlReader]::Parse($uxaml)
  $script:UpdDlgInfo = $UpdInfo
  $script:UpdDlg.Owner = $window
  $script:UpdUi = @{}
  foreach ($n in 'DlgTitle','VerText','CurText','NotesText','InlineNote','DlPanel','DlPhaseText','DlSizeText',
                 'DlTrack','DlFill','ErrPanel','ErrText','SkipChk','UpdBtn','GoBtn','GoTxt',
                 'CancelDlBtn','CancelDlTxt','LaterBtn') {
    $script:UpdUi[$n] = $script:UpdDlg.FindName($n)
  }
  $script:UpdUi.VerText.Text = "新版本 v$($UpdInfo.Version)"
  $script:UpdUi.CurText.Text = "当前 v$($UpdInfo.Current)"
  $notes = "$($UpdInfo.Notes)".Trim()
  $script:UpdUi.NotesText.Text = $(if ($notes) { $notes } else { '（本次更新没有附带说明）' })
  if ($UpdInfo.CanInline) {
    # 绿色版没有独立的解压覆盖通道，统一走安装器：覆盖安装保护会保住 profiles/backup/config，
    # 把安装位置选到现在的目录即可原地升级，在这里就把话说清楚
    $script:UpdUi.InlineNote.Text = '「立即更新」将从官方源（df.ltz88.cn）下载安装包并校验完整性，随后关闭本程序运行安装器。绿色版用户把安装位置选到当前目录即可原地升级，自存方案 / 备份 / 运行状态不会被覆盖。'
  } else {
    # 清单缺 sha256/size 或 setupUrl 过不了白名单安检：内置更新不可用，退回旧行为并留痕
    $script:UpdUi.UpdBtn.Visibility = 'Collapsed'
    $script:UpdUi.InlineNote.Text = '本次更新将打开浏览器前往下载页。'
    if ("$($UpdInfo.InlineDeny)") { Write-Log "内置更新不可用（$($UpdInfo.InlineDeny)），已退回浏览器下载。" }
  }
  $script:UpdDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:UpdDlg.DragMove() })

  # 下载进度轮询：后台 runspace 只写 Synchronized 哈希表，UI 一律在这里（Dispatcher 线程）刷新。
  # 对话框中途被关也让它继续跑到 Done 再回收 runspace——取消清理必须有人等到底。
  $script:DlPollTimer = New-Object Windows.Threading.DispatcherTimer
  $script:DlPollTimer.Interval = [TimeSpan]::FromMilliseconds(250)
  $script:DlPollTimer.Add_Tick({
    $st = $script:DlState
    if (-not $st) { $script:DlPollTimer.Stop(); return }
    if ($script:UpdDlg.IsVisible -and $st.Phase -eq 'downloading') {
      $recv = [long]$st.Received; $totalB = [long]$st.Total
      $pct = $(if ($totalB -gt 0) { [Math]::Min(100, [Math]::Floor($recv * 100.0 / $totalB)) } else { 0 })
      $script:UpdUi.DlSizeText.Text = "{0:N1} MB / {1:N1} MB · {2}%" -f ($recv / 1MB), ($totalB / 1MB), $pct
      $trackW = $script:UpdUi.DlTrack.ActualWidth - 2
      if ($trackW -gt 0) { $script:UpdUi.DlFill.Width = $trackW * $pct / 100 }
    }
    if (-not $st.Done) { return }
    $script:DlPollTimer.Stop()
    try { if ($script:DlJob) { $script:DlJob.EndInvoke($script:DlAsync); $script:DlJob.Dispose() } } catch {}
    $script:DlJob = $null
    if (-not $script:UpdDlg.IsVisible) { return }   # 对话框已关：上面已把后台资源回收完
    if ($st.Phase -eq 'done') {
      $script:UpdUi.DlPhaseText.Text = '下载完成，SHA256 校验通过'
      $script:UpdUi.DlSizeText.Text = "{0:N1} MB · 100%" -f ([long]$st.Total / 1MB)
      $trackW = $script:UpdUi.DlTrack.ActualWidth - 2
      if ($trackW -gt 0) { $script:UpdUi.DlFill.Width = $trackW }
      $script:UpdUi.CancelDlBtn.Visibility = 'Collapsed'
      Write-Log "更新包已下载并通过校验：$($st.File)"
      Show-ConfirmDialog '准备安装' 'READY TO INSTALL' '校验通过，即将关闭本程序并启动安装程序。安装器会请你确认安装位置；覆盖安装不会丢失自存方案和备份。' '关闭并安装' -InfoOnly | Out-Null
      try {
        # 先启动安装器再退出：本程序不退出会占住程序文件，安装器覆盖时必失败
        Start-Process -FilePath $st.File
        $script:UpdDlg.DialogResult = $false
        $window.Close()
      } catch {
        $script:UpdUi.ErrText.Text = "启动安装程序失败：$($_.Exception.Message)"
        $script:UpdUi.ErrPanel.Visibility = 'Visible'
        $script:UpdUi.GoTxt.Text = '改为打开下载页'
        Reset-UpdDialogButtons
        Write-Log "启动安装程序失败：$($_.Exception.Message)"
      }
    } elseif ($st.Phase -eq 'cancelled') {
      Reset-UpdDialogButtons
      Write-Log '已取消更新下载，临时文件已清理。'
    } else {
      # 失败要说人话并给降级出路：改为浏览器打开下载页（旧行为）
      Reset-UpdDialogButtons
      $script:UpdUi.ErrText.Text = "$($st.Error)"
      $script:UpdUi.ErrPanel.Visibility = 'Visible'
      $script:UpdUi.GoTxt.Text = '改为打开下载页'
      Write-Log "内置更新失败：$($st.Error)"
    }
  })

  $script:UpdUi.UpdBtn.Add_Click({
    if ($script:DlState -and -not $script:DlState.Done) { return }
    $script:DlState = [hashtable]::Synchronized(@{
      Received = 0L; Total = [long]$script:UpdDlgInfo.Size; Phase = 'downloading'
      Error = ''; File = ''; Cancel = $false; Done = $false
    })
    foreach ($n in 'SkipChk','UpdBtn','GoBtn','LaterBtn') { $script:UpdUi[$n].Visibility = 'Collapsed' }
    $script:UpdUi.ErrPanel.Visibility = 'Collapsed'
    $script:UpdUi.DlPanel.Visibility = 'Visible'
    $script:UpdUi.DlPhaseText.Text = '正在下载更新…'
    $script:UpdUi.DlSizeText.Text = ''
    $script:UpdUi.DlFill.Width = 0
    $script:UpdUi.CancelDlBtn.Visibility = 'Visible'
    $script:UpdUi.CancelDlBtn.IsEnabled = $true
    $script:UpdUi.CancelDlTxt.Text = '取消下载'
    Write-Log "开始下载更新包：$($script:UpdDlgInfo.SetupUrl)"
    # 下载放后台 runspace：白名单安检、SHA256/大小校验都在 Invoke-BoosterSetupDownload 里强制执行
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($ModulePath, $Url, $Sha, $Bytes, $State)
      try { . $ModulePath; Invoke-BoosterSetupDownload -SetupUrl $Url -Sha256 $Sha -Size $Bytes -State $State }
      catch { $State.Phase = 'failed'; $State.Error = "下载线程异常：$($_.Exception.Message)"; $State.Done = $true }
    })
    foreach ($arg in @($script:UpdaterPath, "$($script:UpdDlgInfo.SetupUrl)",
                       "$($script:UpdDlgInfo.Sha256)", [long]$script:UpdDlgInfo.Size, $script:DlState)) {
      [void]$ps.AddArgument($arg)
    }
    $script:DlJob = $ps
    $script:DlAsync = $ps.BeginInvoke()
    $script:DlPollTimer.Start()
  })
  $script:UpdUi.CancelDlBtn.Add_Click({
    if ($script:DlState -and -not $script:DlState.Done) {
      $script:DlState.Cancel = $true
      $script:UpdUi.CancelDlBtn.IsEnabled = $false
      $script:UpdUi.CancelDlTxt.Text = '正在取消…'
      $script:UpdUi.DlPhaseText.Text = '正在取消下载…'
    }
  })
  $script:UpdUi.GoBtn.Add_Click({
    # 只允许 http/https：清单被篡改成本地路径/其他协议时拒绝打开，防止借更新入口执行文件
    $u = "$($script:UpdDlgInfo.Url)"
    if ($u -match '^https?://') { Start-Process $u } else { Write-Log '更新清单里的下载地址不是网页链接，已拦截。' }
    $script:UpdDlg.DialogResult = $true
  })
  $script:UpdUi.LaterBtn.Add_Click({ $script:UpdDlg.DialogResult = $false })
  # 下载中途直接关掉对话框：请求后台取消，轮询定时器会等它清理完临时文件再回收
  $script:UpdDlg.Add_Closed({
    if ($script:DlState -and -not $script:DlState.Done) { $script:DlState.Cancel = $true }
  })
  $script:UpdDlg.ShowDialog() | Out-Null
  if ($script:UpdUi.SkipChk.IsChecked -and (Get-Command Set-BoosterSkipVersion -ErrorAction SilentlyContinue)) {
    # 返回值必须吞掉：现在函数输出会被调用方接住，落盘结果混进去会把 $skipped 变成数组
    Set-BoosterSkipVersion $UpdInfo.Version | Out-Null
    Write-Log "已设置不再提醒 v$($UpdInfo.Version)。"
    # 返回「用户选择了跳过」：调用方据此把标题栏的更新入口一并收起，语义保持一致
    return $true
  }
  $false
}

function Update-ItemList {
  $ui.ItemPanel.Children.Clear()
  $ui.RiskyPanel.Children.Clear()
  # 变量名不能用 $items：引擎被点源进同一作用域，其 [string[]]$Items 参数会把哈希表强制转成字符串
  $optItems = @(Get-OptItems $script:TargetExe)
  $safe  = @($optItems | Where-Object { $_.Tier -ne 'risky' })
  $risky = @($optItems | Where-Object { $_.Tier -eq 'risky' })

  for ($i = 0; $i -lt $safe.Count; $i++) {
    $st = Get-ItemState $safe[$i]
    $ui.ItemPanel.Children.Add((New-ItemRow $safe[$i] $st ($i -eq $safe.Count - 1))) | Out-Null
  }
  for ($i = 0; $i -lt $risky.Count; $i++) {
    $st = Get-ItemState $risky[$i]
    $ui.RiskyPanel.Children.Add((New-ItemRow $risky[$i] $st ($i -eq $risky.Count - 1))) | Out-Null
  }
  $ui.RiskyGroup.Visibility = $(if ($risky.Count -gt 0) { 'Visible' } else { 'Collapsed' })
  Update-Count
}

# 更新检查间隔（分钟）：做成常量便于调整；验证定时机制时可临时改小
$script:UpdateCheckIntervalMinutes = 30

# 异步检查更新：网络请求放后台运行空间，界面渲染不等它；任何失败静默吞掉。
# 启动时查一次，此后由定时器每 $script:UpdateCheckIntervalMinutes 分钟复查——
# 用户长期挂着软件也能等到标题栏入口亮起，不必重启软件才发现新版（实机诉求）。
function Start-UpdateCheck {
  if (-not (Get-Command Test-BoosterUpdate -ErrorAction SilentlyContinue)) { return }
  # 上一轮检查还没回来就跳过本轮：慢网络下 30 分钟间隔也可能追尾
  if ($script:UpdateCheckBusy) { return }
  $script:UpdateCheckBusy = $true
  try {
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($ModulePath, $Cur)
      try { . $ModulePath; Test-BoosterUpdate -CurrentVersion $Cur } catch { $null }
    }).AddArgument($script:UpdaterPath).AddArgument($script:GuiVersion)
    $script:UpdateJob = $ps
    $script:UpdateAsync = $ps.BeginInvoke()
    $script:UpdateTimer = New-Object Windows.Threading.DispatcherTimer
    $script:UpdateTimer.Interval = [TimeSpan]::FromMilliseconds(700)
    $script:UpdateTimer.Add_Tick({
      if (-not $script:UpdateAsync.IsCompleted) { return }
      $script:UpdateTimer.Stop()
      try {
        $r = @($script:UpdateJob.EndInvoke($script:UpdateAsync))
        $found = $r | Where-Object { $_ } | Select-Object -First 1
        if ($found) {
          # 不再启动即弹框打断用户：只点亮标题栏的常驻入口（Discord 手法），详情由用户点开。
          # 定时复查发现同一版本时只静默刷新信息，日志不重复刷屏
          $isNew = ("$($found.Version)" -ne "$(if ($script:UpdateInfo) { $script:UpdateInfo.Version })")
          $script:UpdateInfo = $found
          $ui.UpdateBtn.ToolTip = "新版本 v$($found.Version) 可用（当前 v$($found.Current)），点击查看详情"
          $ui.UpdateBtn.Visibility = 'Visible'
          if ($isNew) { Write-Log "检测到新版本 v$($found.Version)（当前 v$($found.Current)），点右上角「有新版本」查看详情。" }
        }
      } catch {} finally { $script:UpdateJob.Dispose(); $script:UpdateCheckBusy = $false }
    })
    $script:UpdateTimer.Start()
  } catch { $script:UpdateCheckBusy = $false }
}

$script:TargetExe = $null
$script:PresetList = @()
$script:ApplyingPreset = $false
$script:UpdateInfo = $null

$window.Add_ContentRendered({
  try {
    $hw = Get-HardwareInfo
    $ui.HwGrid.Children.Clear()
    $gpu = ($hw.Gpus | Where-Object { $_.Vendor -in 'NVIDIA','AMD' } | Select-Object -First 1)
    if (-not $gpu) { $gpu = $hw.Gpus | Select-Object -First 1 }
    $cpuShort = ($hw.CPU -replace '^\d+th Gen ', '' -replace '\(R\)|\(TM\)', '' -replace '\s*@.*$', '').Trim()
    $ui.HwGrid.Children.Add((New-HwCard 'CPU' $cpuShort "$($hw.Cores)核 / $($hw.Threads)线程")) | Out-Null
    $ui.HwGrid.Children.Add((New-HwCard 'GPU' $gpu.Name "$($gpu.Vendor) · $(if (@($hw.Gpus).Count -gt 1) { '双显卡' } else { '单显卡' })" -Ribbon)) | Out-Null
    $ui.HwGrid.Children.Add((New-HwCard 'MEMORY' "$($hw.RamGB) GB" "$(if ($hw.IsLaptop) { '笔记本' } else { '台式机' }) / Build $($hw.Build)")) | Out-Null

    Write-Log '开始检测硬件与系统状态…'
    $script:TargetExe = Find-GamePath
    if ($script:TargetExe) {
      $ui.GameText.Text = $script:TargetExe
      Write-Log "目标程序已定位：$script:TargetExe"
    } else {
      $ui.GameText.Text = '未定位 — 点「重新定位」手动选择游戏主程序'
      Write-Log '未自动找到游戏，部分优化项需要手动指定路径'
    }
    Update-ItemList
    Update-PresetList
    $ui.ScanState.Text = '检测完成'
    Write-Log '检测完成。选预设方案或手动勾选后点「执行优化」，带 * 的项需要管理员权限。'
    Start-UpdateCheck
    # 运行期间定时复查：DispatcherTimer 在 UI 线程触发，真正的网络请求仍在后台 runspace，
    # 静默失败的约定不变——断网/超时都不会打扰主界面
    $script:UpdatePeriodicTimer = New-Object Windows.Threading.DispatcherTimer
    $script:UpdatePeriodicTimer.Interval = [TimeSpan]::FromMinutes($script:UpdateCheckIntervalMinutes)
    $script:UpdatePeriodicTimer.Add_Tick({ Start-UpdateCheck })
    $script:UpdatePeriodicTimer.Start()
  } catch {
    $ui.ScanState.Text = '检测失败'
    Write-Log "初始化失败：$($_.Exception.Message)"
  }
})

$ui.TitleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$ui.MinBtn.Add_Click({ $window.WindowState = 'Minimized' })
$ui.UpdateBtn.Add_Click({
  if (-not $script:UpdateInfo) { return }
  # 用户在详情框里勾了「不再提醒此版本」就把入口收起，和跳过语义保持一致
  if (Show-UpdateDialog $script:UpdateInfo) { $ui.UpdateBtn.Visibility = 'Collapsed' }
})
# 执行中途关窗会让备份文件写不出来（备份在全部执行完才落盘），必须拦下
$ui.CloseBtn.Add_Click({
  if ($script:Busy) { Write-Log '正在执行优化，请等本轮执行结束后再关闭。'; return }
  $window.Close()
})

$ui.TabOptBtn.Add_Click({ Select-Tab 'opt' })
$ui.TabRefBtn.Add_Click({ Select-Tab 'ref' })

$ui.BrowseBtn.Add_Click({
  $dlg = New-Object Microsoft.Win32.OpenFileDialog
  $dlg.Filter = '游戏主程序 (*.exe)|*.exe'
  $dlg.Title = '选择三角洲行动主程序（如 DeltaForceClient-Win64-Shipping.exe）'
  if ($dlg.ShowDialog()) {
    $script:TargetExe = $dlg.FileName
    $ui.GameText.Text = $script:TargetExe
    Update-ItemList
    Write-Log "目标程序已更新：$script:TargetExe"
  }
})

$ui.RefreshBtn.Add_Click({ Update-ItemList; Write-Log '状态已刷新。' })

# 全选/全不选（实机诉求）：勾选态只圈「可执行」的项——已就绪项重复执行只会撑大备份；
# 全不选则一视同仁清空。这等同手动改勾选，方案选中态一并清掉（勾选已不再等于该方案）
$ui.SelAllChk.Add_Click({
  $on = ($ui.SelAllChk.IsChecked -eq $true)
  foreach ($row in @($ui.ItemPanel.Children)) {
    $row.Child.Children[0].IsChecked = $(if ($on) { $row.Tag -ne $true } else { $false })
  }
  Update-Count
  if ($ui.PresetBox -and $ui.PresetBox.SelectedIndex -ge 0) {
    $ui.PresetBox.SelectedIndex = -1
    $ui.PresetNote.Text = ''
  }
})

# 复制成功后按钮短暂变「已复制」再复原：给出即时反馈但不打断视线
$script:CopyRevertTimer = New-Object Windows.Threading.DispatcherTimer
$script:CopyRevertTimer.Interval = [TimeSpan]::FromSeconds(1.5)
$script:CopyRevertTimer.Add_Tick({ $script:CopyRevertTimer.Stop(); $ui.CopyLogTxt.Text = '复制' })
$ui.CopyLogBtn.Add_Click({
  $txt = $ui.LogBox.Text
  if (-not $txt) { Write-Log '日志还是空的，没有可复制的内容。'; return }
  # GUI 线程本就是 STA；但 SetText 的冲刷（flush）步骤会被短暂占用剪贴板的进程搅黄而抛
  # CLIPBRD_E_CANT_OPEN——本机实测这种情况下数据其实已经写进去了，所以抛错后先回读确认，
  # 确认不了再用不冲刷的 SetDataObject 兜底（代价只是应用退出后剪贴板内容失效）
  $copied = $false
  try { [Windows.Clipboard]::SetText($txt); $copied = $true }
  catch {
    # 回读确认也可能撞上同一把短锁，稍候重试几次再下结论
    foreach ($attempt in 1..3) {
      try { $copied = ([Windows.Clipboard]::GetText() -eq $txt); break } catch { Start-Sleep -Milliseconds 80 }
    }
    if (-not $copied) {
      try { [Windows.Clipboard]::SetDataObject($txt, $false); $copied = $true } catch {}
    }
  }
  if ($copied) {
    $ui.CopyLogTxt.Text = '已复制'
    $script:CopyRevertTimer.Stop()
    $script:CopyRevertTimer.Start()
  } else {
    Write-Log '复制到剪贴板失败（剪贴板被其他程序占用），请手动选中日志文本按 Ctrl+C 复制。'
  }
})

$ui.GuideBtn.Add_Click({
  $hw = Get-HardwareInfo
  # 顶部醒目标出识别结果：此前用户看不出这份指引是按自己的显卡生成的（实机反馈）
  $banner = "检测到你的显卡：$($hw.MainGpuName)"
  if (@($hw.Gpus).Count -gt 1) { $banner += "`n双显卡机型（核显 + 独显），游戏以独显为准，以下指引按独显给出" }
  Show-ConfirmDialog '显卡指引' 'GPU DRIVER GUIDE' (Get-GpuGuideText $hw.MainGpuVendor) '知道了' -InfoOnly -Banner $banner | Out-Null
})

# ---------- 预设方案 ----------

$ui.PresetBox.Add_SelectionChanged({
  $idx = $ui.PresetBox.SelectedIndex
  if ($idx -lt 0 -or $idx -ge $script:PresetList.Count) { return }
  try {
    $p = $script:PresetList[$idx]
    $ids = @(Resolve-PresetItems $p.Id $script:TargetExe)
    $script:ApplyingPreset = $true
    try {
      foreach ($row in (@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children))) {
        $cb = $row.Child.Children[0]
        $cb.IsChecked = ($ids -contains $cb.Tag)
      }
    } finally { $script:ApplyingPreset = $false }
    $ui.PresetNote.Text = $p.Note
    Update-Count
    Write-Log "已套用方案「$($p.Name)」（$($ids.Count) 项）"
  } catch { Write-Log "套用方案失败：$($_.Exception.Message)" }
})

$ui.SavePresetBtn.Add_Click({
  try {
    $ids = @((@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children)) |
             Where-Object { $_.Child.Children[0].IsChecked } | ForEach-Object { $_.Child.Children[0].Tag })
    if ($ids.Count -eq 0) { Write-Log '未勾选任何优化项，无法存为方案。'; return }
    $newName = Show-NameDialog
    if (-not $newName) { return }
    Save-UserPreset $newName $ids | Out-Null
    Update-PresetList
    for ($i = 0; $i -lt $script:PresetList.Count; $i++) {
      if (-not $script:PresetList[$i].Builtin -and $script:PresetList[$i].Name -eq $newName) {
        $ui.PresetBox.SelectedIndex = $i; break
      }
    }
    Write-Log "方案「$newName」已保存（$($ids.Count) 项）。"
  } catch { Write-Log "保存方案失败：$($_.Exception.Message)" }
})

$ui.DelPresetBtn.Add_Click({
  try {
    $idx = $ui.PresetBox.SelectedIndex
    if ($idx -lt 0) { Write-Log '请先在下拉里选中要删除的方案。'; return }
    $p = $script:PresetList[$idx]
    if ($p.Builtin) { Write-Log "「$($p.Name)」是内置方案，不能删除。"; return }
    if (-not (Show-ConfirmDialog '确认删除' 'CONFIRM DELETE' "删除自存方案「$($p.Name)」？删除后不可恢复。" '删除')) { return }
    Remove-UserPreset $p.Id | Out-Null
    Update-PresetList
    $ui.PresetNote.Text = ''
    Write-Log "方案「$($p.Name)」已删除。"
  } catch { Write-Log "删除方案失败：$($_.Exception.Message)" }
})

$ui.ApplyBtn.Add_Click({
  try {
    $ids = @($ui.ItemPanel.Children | Where-Object { $_.Child.Children[0].IsChecked } |
             ForEach-Object { $_.Child.Children[0].Tag })
    if ($ids.Count -eq 0) { Write-Log '未勾选任何优化项。'; return }
    $names = @(Get-OptItems $script:TargetExe | Where-Object { $ids -contains $_.Id } | ForEach-Object { $_.Name })
    $msg = "将执行以下 $($ids.Count) 项优化（改动前自动备份，可一键还原）：`n`n" +
           (@($names | ForEach-Object { "· $_" }) -join "`n")
    if (-not (Show-ConfirmDialog '确认执行' 'CONFIRM APPLY' $msg '执行优化')) { return }
    Set-BusyState $true
    $ui.ProgressPanel.Visibility = 'Visible'
    $ui.ProgFill.Width = 0
    $ui.ProgText.Text = '准备执行…'
    $ui.ProgCount.Text = ''
    Write-Log "开始执行 $($ids.Count) 项优化…"
    # 进度回调逐项刷新界面并实时落日志，不再等全部跑完才一次性输出
    $r = Invoke-Apply $ids $script:TargetExe $false ${function:Update-ApplyProgress}
    $okN = @($r.Results | Where-Object Ok).Count
    $attList = @($r.Results | Where-Object Attention)
    $skipList = @($r.Results | Where-Object { -not $_.Ok -and $_.Skipped })
    $failList = @($r.Results | Where-Object { -not $_.Ok -and -not $_.Skipped -and -not $_.Attention })
    $total = @($r.Results).Count
    # 明确的完成度结论：进度条区和日志各给一份，失败项单独列出让用户一眼看到；
    # 体检发现的问题单列——那是检测项立功了，混进「失败」会让用户误以为工具坏了
    $att = $(if ($attList.Count -gt 0) { " / $($attList.Count) 项体检发现问题" })
    $ui.ProgText.Text = "执行完成：$okN 成功 / $($failList.Count) 失败 / $($skipList.Count) 跳过$att"
    $ui.ProgCount.Text = "共 $total 项"
    if ($r.Backup) { Write-Log "备份已保存：$($r.Backup)" }
    Write-Log "执行完成：共 $total 项 — $okN 成功、$($failList.Count) 失败、$($skipList.Count) 跳过$(if ($attList.Count -gt 0) { "、$($attList.Count) 项体检发现问题" })。"
    if ($failList.Count -gt 0) {
      Write-Log "以下 $($failList.Count) 项失败，请把日志原文反馈或运行 scripts\diagnose.ps1 排查："
      foreach ($x in $failList) { Write-Log "  [失败] $($x.Name) — $($x.Msg)" }
    }
    if ($attList.Count -gt 0) {
      Write-Log "体检发现以下问题（工具改不了，需按提示手动处理）："
      foreach ($x in $attList) { Write-Log "  [提示] $($x.Name) — $($x.Msg)" }
      # 日志里的纯文本链接没人会手抄（实机反馈）：弹对话框给逐步教程和可点击的下载按钮
      Show-HealthDialog $attList
    }
    Update-ItemList
    # 醒目的重启提醒取代此前日志末尾的一行小字（实机反馈根本注意不到）：
    # 引擎已在每条结果上标好 Reboot（成功且确需重启才为 true），全失败/全即时项不弹
    $rebootList = @($r.Results | Where-Object { $_.Reboot })
    if ($rebootList.Count -gt 0) {
      $rebootNames = @($rebootList | ForEach-Object { $_.Name })
      Write-Log "以下 $($rebootList.Count) 个成功项需重启电脑后完全生效：$($rebootNames -join '、')。"
      if (Show-RebootDialog $rebootNames) {
        # 重启是破坏性动作：即便用户点了「立即重启」也必须再确认一次，双重确认不可省
        if (Show-ConfirmDialog '确认重启' 'CONFIRM REBOOT' '确定现在重启电脑？未保存的工作会丢失。确认后系统将在 5 秒内重启。' '确认重启') {
          Write-Log '已确认重启，系统将在 5 秒内重启…'
          Invoke-SystemReboot
        } else { Write-Log '已取消重启，稍后请自行重启电脑以让优化完全生效。' }
      } else { Write-Log '你选择了稍后重启，优化项将在下次重启后完全生效。' }
    }
  } catch { Write-Log "执行失败：$($_.Exception.Message)" }
  finally { Set-BusyState $false }
})

$ui.RestoreBtn.Add_Click({
  try {
    if (-not (Show-ConfirmDialog '确认还原' 'CONFIRM RESTORE' '按最近一次备份还原全部改动？还原后各项会回到优化前的状态。' '还原设置')) { return }
    Set-BusyState $true
    # 此前同步跑完才刷新，界面「卡一下」就结束，用户不知道还原有没有在干活（实测吐槽）；
    # 现在和执行优化共用进度面板，逐项推进 + 结束弹明确的完成提示
    $ui.ProgressPanel.Visibility = 'Visible'
    $ui.ProgFill.Width = 0
    $ui.ProgText.Text = '正在还原…'
    $ui.ProgCount.Text = ''
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $r = Invoke-Restore $null ${function:Update-RestoreProgress}
    $failN = @($r.Failed).Count
    $skipN = @($r.Skipped).Count
    $bakName = Split-Path -Leaf $r.File
    $ui.ProgText.Text = "还原完成：$($r.RestoredOps) 项已还原 / $failN 项失败$(if ($skipN -gt 0) { " / $skipN 项跳过（无实际影响）" })"
    $ui.ProgCount.Text = "备份：$bakName"
    Write-Log "已还原 $($r.RestoredOps) 项改动（备份：$($r.File)）"
    foreach ($f in $r.Failed) { Write-Log "[还原失败] $f" }
    # 跳过与失败必须分开呈现：跳过是「删不掉但不影响任何生效设置」，混在失败里会吓到用户
    foreach ($s in $r.Skipped) { Write-Log "[还原跳过] $s" }
    foreach ($n in $r.Notes) { Write-Log "[提示] $n" }
    Update-ItemList
    # 成功与否都要有明确收尾：全成给定心丸，有失败的把数量点出来引导看日志
    $sum = "已按备份「$bakName」还原 $($r.RestoredOps) 项改动。" +
           $(if ($skipN -gt 0) { "`n`n$skipN 项跳过：工具自建电源方案里的残留设置，该方案已停用，无实际影响。" }) +
           $(if ($failN -gt 0) { "`n`n有 $failN 项还原失败，明细见运行日志。" }
             elseif ($skipN -gt 0) { "`n`n其余全部还原成功，各项已回到优化前的状态。" }
             else { "`n`n全部还原成功，各项已回到优化前的状态。" })
    Show-ConfirmDialog '还原完成' 'RESTORE DONE' $sum '知道了' -InfoOnly | Out-Null
  } catch { Write-Log "还原失败：$($_.Exception.Message)" }
  finally { Set-BusyState $false }
})

$window.ShowDialog() | Out-Null
