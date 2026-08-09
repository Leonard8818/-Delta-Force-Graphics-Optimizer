<#
  DeltaForceBooster 图形界面 — v0.19.2
  视觉基准：三角洲行动国服官网 df.qq.com 实测提炼：近黑微青顶栏 #0D1417 + 页面青绿细
  渐变 #0A1512→#10201C + 正绿 CTA #00E884（斜切角 + 等高线纹理）+ 金色分类标签 #E5C46A
  + 中英上下叠排分区标题 + 侧边刻度尺装饰 + 拉字距装饰分隔线。

  v0.19.2：①体检项不再因「上次已通过」而在套用方案时被跳过（VC++ 体检等于只检测一次）；
        ②随引擎 v0.16.3 加入实验项「清理着色器缓存」，界面按普通项呈现，项名与
        说明里写明不保证生效、不产生备份。
  v0.19.1：性能汇总增加粗粒度优化强度（未使用/轻量/均衡/深度），不发送具体勾选项、
        自存方案名称或方案内容，用于同一匿名设备的优化前后配对比较。
  v0.19.0：显卡型号改从驱动/NVML 读取真实硬件，不再让伪装值污染界面和统计；游戏启动后
        自动采样 120 秒，记录平均 FPS、1% Low、GPU 占用率、温度和功耗汇总；加入最低
        支持版本策略，低于门槛的客户端不可跳过更新。
  v0.18.4：显卡软件缺失时明确指引点击官方下载按钮；自动检测到新版本时直接弹出
        更新详情，不再只显示标题栏入口。
  v0.18.3：主推全套加入显卡型号伪装，仍保留独立二次确认和手动目标型号选择。
  v0.18.2：修复双显卡笔记本误把 AMD/Intel 核显用于显卡指引，改为稳定选择独显；
        NVIDIA 笔记本补充 Game Ready 驱动选择说明。
  v0.18.1：修复显卡型号伪装参数与 GUI 状态变量同名，导致程序启动时直接退出。
  v0.17：①「危险区域」改为中性的「显卡型号伪装」，RTX 30 系默认 705 Ti、40/50 系默认
        1050 Ti，并可在界面手动切换；②修复内置更新覆盖 app.ico 时可能被旧窗口占用。
  v0.16.2：打包修正版——v0.16.1 的安装包误将构建者本机的自存方案（profiles\）打了进去，
        装完会凭空多出别人的方案。界面与引擎均无改动，仅版本号跟随。
  v0.16.1：随引擎 v0.15.1 发版——修复「电源计划隐藏项」还原被误报失败（残留值留在还原后
        不生效的方案里时不再当成失败）。界面无改动，仅版本号跟随。
  v0.16：①主窗口 Closing 忙碌守卫（WM_CLOSE/Alt+F4 不再能中断执行中的优化/还原）；
        ②配合引擎的实时备份：备份写盘失败时日志+弹窗双通道警告并给出手动还原线索；
        ③危险区域勾选真正生效——此前勾了也不执行、不提示；现在有独立的高风险二次
        确认（逐项列名称与风险说明），确认后才带 AllowRisky 执行，自存方案里的
        risky 项也因此在 GUI 里走得通。
  v0.15：①首次启动的免责声明门控（滚到底才能同意，同意状态与声明版本号存 config\，
        版本号 +1 即可让所有人重新确认）；②「上传诊断报告」：报告本地组装 + 脱敏后
        经用户确认才上传，返回取件码；③更新一键完成——校验通过直接静默安装并自启新版，
        安装阶段转圈禁操作，失败给降级入口；④「检查更新」移到标题栏；⑤显卡指引改为
        驱动层内容 + 控制面板一键入口（装了才给按钮）。
  v0.14：VC++ 体检指引改用 aka.ms/vs/18；主推预设 Id 改为 main。
  v0.13：「游戏内设置参考」页按实机菜单重排；启动默认选中主推方案；全局深色 Chrome
        资源字典（对话框是独立 Window，不挂就是系统白滚动条）。
  早期版本的变更见 git 历史；关键结论都已就地写在对应代码处的注释里。

  双击根目录「启动优化工具.exe」（或后备的 .bat）运行；本文件点源加载
  scripts\delta-booster.ps1 作为引擎，scripts\updater.ps1 作为更新模块。
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
$script:GuiVersion = '0.19.2'
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
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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

    <!-- 深色滚动条样式已移入 $script:ThemeResXaml 共享资源字典（v0.13）：
         对话框是独立 Window 不继承这里的资源，样式只放主窗口时对话框滚动条仍是
         系统白色（实机反馈）。主窗口在 Parse 后 MergedDictionaries 引同一份实例 -->

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
          <TextBlock Text="[ v0.19.2 ]" Style="{StaticResource Mono}" Foreground="{StaticResource Green}" Margin="9,0,0,0"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <!-- 手动检查更新：用户要求放在最上方。与右侧「有新版本」胶囊分工不同——
               胶囊只在已发现新版时出现，这个按钮任何时候都能主动查一次 -->
          <Button x:Name="CheckUpdBtn" Content="检查更新" Style="{StaticResource Ghost}"
                  Height="24" FontSize="11" VerticalAlignment="Center" Margin="0,0,10,0"/>
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

    <!-- 标签页导航：优化 / 游戏内设置参考 / 运行日志 -->
    <Border Grid.Row="1" Background="{StaticResource TopBar}" BorderBrush="{StaticResource Line}"
            BorderThickness="0,0,0,1">
      <StackPanel Orientation="Horizontal" Margin="15,0,0,0">
        <Button x:Name="TabOptBtn" Content="优化" Style="{StaticResource TabBtn}" Tag="on"/>
        <Button x:Name="TabRefBtn" Content="游戏内设置参考" Style="{StaticResource TabBtn}" Tag=""/>
        <Button x:Name="TabLogBtn" Style="{StaticResource TabBtn}" Tag="">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="运行日志" VerticalAlignment="Center"/>
            <!-- 角标：日志挪到独立页后，出了失败/体检问题得有个「这里有东西该看」的信号。
                 前景色写死，免得被标签页选中态的 Foreground 触发器染成绿色 -->
            <Border x:Name="LogBadge" Visibility="Collapsed" Background="{StaticResource Danger}"
                    CornerRadius="7" MinWidth="15" Height="15" Margin="7,0,0,0" VerticalAlignment="Center">
              <TextBlock x:Name="LogBadgeTxt" Text="" Foreground="#FFFFFFFF" FontSize="9" FontWeight="Bold"
                         Margin="5,0,5,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </StackPanel>
        </Button>
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

          <Expander x:Name="RiskyGroup" Margin="0,10,0,0" Visibility="Collapsed" Foreground="{StaticResource TextPri}">
            <Expander.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="显卡型号伪装" Foreground="{StaticResource TextPri}" FontSize="12"/>
                <TextBlock Text="按显卡代际推荐 · 可手动选择目标型号" Style="{StaticResource Mono}" Margin="10,0,0,0"/>
              </StackPanel>
            </Expander.Header>
            <Border BorderBrush="{StaticResource Line}" BorderThickness="1" Background="{StaticResource PanelDeep}" Margin="0,6,0,0">
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

    <!-- 游戏内设置参考页：纯展示（内容由代码按 data\streamer-settings.json 构建） -->
    <Grid Grid.Row="2" x:Name="RefPage" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="21,10">
        <StackPanel x:Name="RefPanel"/>
      </ScrollViewer>
    </Grid>

    <!-- 运行日志页：逐条文本记录。执行进度与结果汇总留在优化页，用户不必为看结果切页 -->
    <Grid Grid.Row="2" x:Name="LogPage" Visibility="Collapsed" Margin="21,10,21,10">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <Grid Grid.Row="0" Margin="0,0,0,7">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock Text="运行日志" Style="{StaticResource HeadCn}"/>
          <TextBlock Text="RUN LOG" Style="{StaticResource HeadEn}"/>
          <Border Style="{StaticResource HeadBar}"/>
        </StackPanel>
        <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                VerticalAlignment="Bottom" Margin="12,0,12,4"/>
        <!-- 一键复制：反馈问题时直接整段拷走，不用在小窗里手动拖选。
             图标 Path 用固定坐标（不加 Stretch）：归一化坐标 + Stretch 会被撑大（教训 #3） -->
        <Button x:Name="CopyLogBtn" Grid.Column="2" Style="{StaticResource Ghost}" Height="24"
                FontSize="11" VerticalAlignment="Bottom" ToolTip="复制全部日志到剪贴板">
          <StackPanel Orientation="Horizontal">
            <Path Data="M 0,3 L 0,11 L 6,11 L 6,3 Z M 3,0 L 9,0 L 9,8 L 6,8" Stroke="#FF00E884"
                  StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center"/>
            <TextBlock x:Name="CopyLogTxt" Text="复制" Margin="5,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
      </Grid>
      <Border Grid.Row="1" Background="{StaticResource LogBg}" BorderBrush="{StaticResource Line}" BorderThickness="1">
        <TextBox x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="Transparent"
                 Foreground="#FF9AA5A0" FontFamily="Consolas" FontSize="11" Padding="10,7"/>
      </Border>
      <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,9,0,0">
        <!-- 把诊断信息打包发给作者排查；上传前列清单请用户确认，不会静默发送 -->
        <Button x:Name="ReportBtn" Content="上传诊断报告" Style="{StaticResource Ghost}" Width="132"/>
        <TextBlock Text="上传前会列出内容并请你确认，路径中的用户名会脱敏" Style="{StaticResource Mono}"
                   Margin="12,0,0,0"/>
      </StackPanel>
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
        <Button x:Name="RestoreBtn" Content="还原设置" Style="{StaticResource Ghost}" Width="118" Margin="9,0,0,0"/>
        <Button x:Name="RefreshBtn" Content="重新检测" Style="{StaticResource Ghost}" Width="104" Margin="9,0,0,0"/>
        <Button x:Name="GuideBtn" Content="显卡指引" Style="{StaticResource Ghost}" Width="104" Margin="9,0,0,0"/>
      </StackPanel>
      <!-- 执行进度留在优化页：日志挪走后，这里是执行期间唯一的实时反馈 -->
      <StackPanel x:Name="ProgressPanel" Visibility="Collapsed" Margin="0,9,0,0">
        <Border x:Name="ProgTrack" Height="6" Background="{StaticResource PanelDeep}"
                BorderBrush="{StaticResource Line}" BorderThickness="1">
          <Border x:Name="ProgFill" Background="{StaticResource Green}" HorizontalAlignment="Left" Width="0"/>
        </Border>
        <Grid Margin="0,5,0,0">
          <!-- 换行而不是截断：执行完成后这里要放下汇总 + 失败项名，截掉就等于没说 -->
          <TextBlock x:Name="ProgText" Style="{StaticResource Mono}" Foreground="{StaticResource TextSec}"
                     Text="" TextWrapping="Wrap" HorizontalAlignment="Left" Margin="0,0,120,0"/>
          <TextBlock x:Name="ProgCount" Style="{StaticResource Mono}" Foreground="{StaticResource Green}"
                     Text="" HorizontalAlignment="Right"/>
        </Grid>
      </StackPanel>
    </StackPanel>

    <!-- 页脚 HUD 线：等宽小字 + 金色短段 + 空心小方块 -->
    <Grid Grid.Row="4" Margin="29,0,29,9" VerticalAlignment="Center">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <!-- 非官方声明常驻页脚：NOTICE.md 的核心一句，用户不会主动去翻文件 -->
      <TextBlock Grid.Column="0" Text="非官方工具 · 与腾讯及《三角洲行动》官方无关" Style="{StaticResource Mono}" FontSize="9"/>
      <Border Grid.Column="1" Width="26" Height="2" Background="{StaticResource Gold}" VerticalAlignment="Center" Margin="9,0,0,0"/>
      <Border Grid.Column="2" Height="1" Background="{StaticResource LineSoft}" VerticalAlignment="Center" Margin="9,0"/>
      <Border Grid.Column="3" Width="5" Height="5" BorderBrush="{StaticResource Green}" BorderThickness="1" VerticalAlignment="Center" Margin="0,0,9,0"/>
      <StackPanel Grid.Column="4" Orientation="Horizontal">
        <TextBlock Text="[ V0.19.2 ] 改动前自动备份 · 可一键还原设置" Style="{StaticResource Mono}" FontSize="9"/>
        <!-- 随时可重看免责声明：首次启动的门控之外也得留个常驻入口 -->
        <Button x:Name="DisclaimerBtn" Style="{StaticResource Ghost}" Height="17" FontSize="9"
                Margin="10,0,0,0" Content="免责声明"/>
      </StackPanel>
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
    # 直接用文件 Uri 会让 WPF 的解码器长期持有 app.ico，覆盖更新时安装器因此报“正由另
    # 一进程使用”。OnLoad 把图标完整读进内存并立即释放文件句柄，窗口生命周期不再锁文件。
    $icoStream = [IO.File]::Open($icoPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
      $ico = New-Object Windows.Media.Imaging.BitmapImage
      $ico.BeginInit()
      $ico.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
      $ico.StreamSource = $icoStream
      $ico.EndInit()
      $ico.Freeze()
      $window.Icon = $ico
    } finally { $icoStream.Dispose() }
  }
} catch {}
# ---------- 全局深色 Chrome 资源字典 ----------
# 对话框是 XamlReader 另行 Parse 的独立 Window，不继承主窗口 Window.Resources——样式只挂
# 主窗口时，对话框里的滚动条仍是系统白色（实机反馈）。这里把 WPF 默认浅色的零件
# （ScrollBar 纵横双向、ToolTip、右键菜单、文本选中色、焦点虚线框）一次做成深色，
# 主窗口与全部对话框引用同一份实例。
$script:ThemeResXaml = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Style TargetType="ScrollBar">
    <Setter Property="Width" Value="6"/>
    <!-- Min/Max 必须一起钉死：主题默认样式仍会给 ScrollBar 兜一个 MinWidth≈17，
         而 WPF 布局钳制里 Min 压过 Max 和 Width，不清零就永远是系统宽度（实测 17px） -->
    <Setter Property="MinWidth" Value="0"/>
    <Setter Property="MaxWidth" Value="6"/>
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
    <Style.Triggers>
      <!-- 横向滚动条（游戏内设置参考页的对照表会用到）：老样式只做了纵向模板，
           横向一旦出现会被 Width=6 挤成一条竖线 -->
      <Trigger Property="Orientation" Value="Horizontal">
        <Setter Property="Width" Value="Auto"/>
        <Setter Property="MaxWidth" Value="1000000"/>
        <Setter Property="Height" Value="6"/>
        <Setter Property="MinHeight" Value="0"/>
        <Setter Property="MaxHeight" Value="6"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="ScrollBar">
              <Grid Background="Transparent">
                <Track x:Name="PART_Track">
                  <Track.DecreaseRepeatButton>
                    <RepeatButton Command="ScrollBar.PageLeftCommand" Opacity="0" Focusable="False"/>
                  </Track.DecreaseRepeatButton>
                  <Track.IncreaseRepeatButton>
                    <RepeatButton Command="ScrollBar.PageRightCommand" Opacity="0" Focusable="False"/>
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
      </Trigger>
    </Style.Triggers>
  </Style>
  <!-- ToolTip：默认是白底系统气泡 -->
  <Style TargetType="ToolTip">
    <Setter Property="Background" Value="#FF0E1B17"/>
    <Setter Property="BorderBrush" Value="#FF2C443B"/>
    <Setter Property="Foreground" Value="#FF9AA5A0"/>
    <Setter Property="Padding" Value="9,5"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToolTip">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="1" Padding="{TemplateBinding Padding}">
            <ContentPresenter/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <!-- TextBox 右键菜单（复制/粘贴）：默认白底。项目里没有子菜单，简化模板即可 -->
  <Style TargetType="ContextMenu">
    <Setter Property="Background" Value="#FF0E1B17"/>
    <Setter Property="BorderBrush" Value="#FF2C443B"/>
    <Setter Property="Foreground" Value="#FF9AA5A0"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ContextMenu">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="1" Padding="2">
            <ItemsPresenter/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="MenuItem">
    <Setter Property="Foreground" Value="#FF9AA5A0"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="MenuItem">
          <Border x:Name="BD" Background="Transparent" Padding="12,5">
            <ContentPresenter ContentSource="Header" RecognizesAccessKey="True"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsHighlighted" Value="True">
              <Setter TargetName="BD" Property="Background" Value="#FF12291F"/>
              <Setter Property="Foreground" Value="#FF00E884"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter Property="Foreground" Value="#FF4A554F"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="Separator">
    <Setter Property="Background" Value="#FF1B2E28"/>
    <Setter Property="Height" Value="1"/>
    <Setter Property="Margin" Value="4,2"/>
  </Style>
  <!-- 文本选中色：默认的系统蓝在青绿主题里最扎眼；焦点虚线框一并去掉 -->
  <Style TargetType="TextBox">
    <Setter Property="SelectionBrush" Value="#8000E884"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  </Style>
  <!-- 对话框里的按钮/勾选框都是行内模板、没挂命名样式，隐式样式只补焦点虚线框，
       不设 Template 不会覆盖行内模板 -->
  <Style TargetType="Button">
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  </Style>
  <Style TargetType="CheckBox">
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  </Style>
</ResourceDictionary>
'@
$script:ThemeRes = [Windows.Markup.XamlReader]::Parse($script:ThemeResXaml)
$window.Resources.MergedDictionaries.Add($script:ThemeRes)

$ui = @{}
foreach ($n in 'TitleBar','MinBtn','CloseBtn','UpdateBtn','ScanState','HwGrid','GameText','BrowseBtn','CountText',
               'SelAllChk',
               'ItemPanel','RiskyGroup','RiskyPanel','ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','CheckUpdBtn',
               'ReportBtn','DisclaimerBtn','LogBox',
               'PresetBox','SavePresetBtn','DelPresetBtn','PresetNote',
               'TabOptBtn','TabRefBtn','TabLogBtn','LogBadge','LogBadgeTxt',
               'OptPage','RefPage','LogPage','RefPanel','ActionRow',
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
  # 行 Tag 存检测状态：全选框与方案据此只圈「可执行」的项（$true=已就绪，跳过）。
  # 体检项例外，一律记 $null：「已就绪就别重复执行」是给写入类项目省备份用的，而体检
  # 不写任何东西，上次通过不代表这次仍然正常（运行库可能被别的软件装崩）。此前 VC++
  # 体检一旦通过，套方案时就再也不会被勾上，等于永远只检测一次
  $row.Tag = $(if ($Item.Kind -eq 'check') { $null } else { $State.Optimized })

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
  if ($Item.Id -eq 'gpu-name-spoof') {
    $modelBox = New-Object Windows.Controls.ComboBox
    $modelBox.Style = $window.FindResource('TacCombo')
    $modelBox.Width = 220
    $modelBox.Margin = New-Object Windows.Thickness 0, 0, 8, 0
    foreach ($model in @(Get-GpuSpoofModels)) { [void]$modelBox.Items.Add($model) }
    $selectedModel = $(if ($script:SelectedGpuSpoofModel -and $modelBox.Items.Contains($script:SelectedGpuSpoofModel)) {
                         $script:SelectedGpuSpoofModel
                       } else { $Item.SpoofModel })
    $modelBox.SelectedItem = $selectedModel
    $script:SelectedGpuSpoofModel = "$selectedModel"
    $modelBox.ToolTip = '选择要向系统和游戏上报的显卡型号'
    $modelBox.Add_SelectionChanged({
      if ($this.SelectedItem) { $script:SelectedGpuSpoofModel = "$($this.SelectedItem)" }
    })
    $tail.Children.Add($modelBox) | Out-Null
  }
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
    # 主推方案加星标突出（实机诉求）；星标只是显示层修饰，判定用内置 Id
    $star = $(if ($p.Id -eq 'main') { '★ ' } else { '' })
    $ui.PresetBox.Items.Add("$star$($p.Name)$(if (-not $p.Builtin) { '（自存）' })") | Out-Null
  }
}

function Write-Log([string]$Msg) {
  # 先算好整行再传入：方法括号内的逗号会被当成第二个方法参数，-f 拿不到 $Msg 导致 {1} 越界
  $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $Msg
  # 追加前先判断用户是不是正贴着底部看：他手动上滚翻历史时不该被新日志拽回去。
  # 余量 2px 容忍取整误差；内容还没撑满视口时 ExtentHeight<=ViewportHeight，照样算「在底部」
  $box = $ui.LogBox
  $atEnd = ($box.ExtentHeight -le $box.ViewportHeight + 2) -or
           (($box.VerticalOffset + $box.ViewportHeight) -ge ($box.ExtentHeight - 2))
  $box.AppendText("$line`r`n")
  if ($atEnd) { $box.ScrollToEnd() }
}

# ---------- 体检问题的解决办法（教程 + 可点击的官方下载入口） ----------

# 红线：下载链接只能来自这里的硬编码常量，绝不从检测输出/数据文件/网络取——
# 按钮只负责用浏览器打开微软官方地址，本工具自身绝不下载或执行任何安装包
$script:CheckHelp = @{
  'vcredist-check' = @{
    Title = 'VC++ v14 运行库缺失'
    Tutorial = @(
      'VC++ 运行库是游戏和很多软件依赖的微软组件。x64 与 x86 是两套相互独立的运行库，各自服务对应位数的程序：缺失才是真问题（依赖它的程序无法启动）；两套版本不同步很常见、多数机器上无害，本工具只做中性提示，不算问题。'
      ''
      '修复步骤：'
      '1. 点下方按钮下载 x64 与 x86 两个安装包（微软官方链接、当前最新的 vs/18 线，浏览器打开）；'
      '2. 依次双击安装——直接覆盖安装即可，不需要先卸载旧版本；'
      '3. 若双击后看到的是「修复 / 卸载」而不是「安装」，说明系统里已有同版本——选「修复」即可；'
      '4. 若报错 0x80070666「无法安装此产品，因为已安装更新的版本」——说明你系统里的版本比安装包更新，这是正常的，不用处理，也不要为此去卸载；'
      '5. 装完重启电脑，回到本工具点「重新检测」，确认此项变成「正常」；'
      '6. 想统一 x64/x86 版本时，给两个架构装同一条最新线（下方 vs/18 链接）的包，不要装旧线；'
      '7. 只有在缺失某架构、或确实反复闪退且已排除其他原因时，才考虑到「设置 → 应用 → 安装的应用」里只卸载对应架构的「Microsoft Visual C++ 2015-2022 Redistributable」然后重装。切勿把列表里其他年份的 VC++ 一并卸掉——2010/2012/2013 是各自独立的运行库，很多软件还依赖它们。'
    ) -join "`n"
    Links = @(
      @{ Text = '下载 x64 运行库'; Url = 'https://aka.ms/vs/18/release/vc_redist.x64.exe' }
      @{ Text = '下载 x86 运行库'; Url = 'https://aka.ms/vs/18/release/vc_redist.x86.exe' }
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
  # 独立 Window 不继承主窗口资源：不挂共享字典，对话框滚动条就是系统白色（实机反馈）
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
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

# ---------- 游戏内设置参考页（纯展示，数据来自 data\streamer-settings.json） ----------

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
  $wd = New-WrapText '下表是头部主播公开的游戏内画质设置记录，请进入游戏后在「设置 → 视频」页签里手动对照调整。主播设置随游戏版本和硬件不同而变化，不保证适合你的机器。' $script:C.TextSec 11
  $wd.Margin = New-Object Windows.Thickness 0, 4, 0, 0
  $wsp.Children.Add($wd) | Out-Null
  $warn.Child = $wsp
  $ui.RefPanel.Children.Add($warn) | Out-Null

  if (-not (Test-Path -LiteralPath $script:DataFile)) {
    Add-RefNotice '数据尚未就绪' '游戏内设置参考数据（data\streamer-settings.json）还没有生成。数据到位后切回本页会自动加载。'
    return
  }
  $data = $null
  try { $data = Get-Content -LiteralPath $script:DataFile -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { Add-RefNotice '数据读取失败' "streamer-settings.json 暂时无法解析（可能正在生成中）：$($_.Exception.Message)"; return }

  $streamers = @($data.streamers | Where-Object { $_ })
  if ($streamers.Count -eq 0) { Add-RefNotice '数据尚未就绪' '数据文件里还没有主播条目。'; return }

  # 行头顺序优先用数据声明的 settings_schema。v0.12 起 schema 项支持 { name, group }
  # 对象——group 即游戏内「设置 → 视频」页签下的菜单分组（v0.13 按实机录像核对，
  # 一级页签是「视频」不是「画面」）；老格式的纯字符串仍能读，
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

  # 分组依据要如实交代：优先用数据文件里的 schema_note（v0.13 起写明依据实机录像
  # 逐帧核对 + 随版本可能变动），老数据没有分组信息时提示这是兜底展示
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
      # 路径按实机菜单给（v0.13）：一级页签是「视频」；「显示设置」是本表的归类名，
      # 游戏里顶部这组没有组名，路径只写到「设置 → 视频」为止，别让用户找一个不存在的三级菜单
      $gh = New-Text $(if ($gName -eq '其他') { '未归入游戏菜单的项' }
                       elseif ($gName -eq '显示设置') { '游戏内「设置 → 视频」顶部（游戏内未标组名）' }
                       else { "游戏内「设置 → 视频 → $gName」" }) $script:C.TextMut 10 -Mono
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

# ---------- 免责声明门控 ----------

# 声明内容有实质修改时把这个数字 +1：配置里记的版本与此不符即重新弹一次，
# 老用户不会因为条款改了还停留在旧版本的「已同意」上
$script:DisclaimerVersion = '4'
$script:DisclaimerFile = Join-Path $script:RootDir 'DISCLAIMER.md'

# 同意状态与 updater 的配置同目录：profiles\ 下的 *.json 会被引擎当预设方案扫出来
function Get-DisclaimerConfigPath {
  $d = Join-Path $script:RootDir 'config'
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  Join-Path $d 'disclaimer.json'
}

function Test-DisclaimerAccepted {
  try {
    $f = Get-DisclaimerConfigPath
    if (-not (Test-Path -LiteralPath $f)) { return $false }
    $j = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
    return ("$($j.Version)" -eq $script:DisclaimerVersion)
  } catch { return $false }
}

function Set-DisclaimerAccepted {
  $o = @{ Version = $script:DisclaimerVersion; AcceptedAt = (Get-Date).ToString('s') }
  [IO.File]::WriteAllText((Get-DisclaimerConfigPath), ($o | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
}

# 文件缺失（残缺包/被杀软删了）不能等于放行：退回内嵌短文本，门控照常拦
function Get-DisclaimerText {
  try {
    if (Test-Path -LiteralPath $script:DisclaimerFile) {
      $t = [IO.File]::ReadAllText($script:DisclaimerFile, [Text.Encoding]::UTF8)
      if ("$t".Trim()) { return $t }
    }
  } catch {}
  @(
    '# 使用前必读'
    ''
    '未能读取完整声明文件（DISCLAIMER.md 缺失），以下是核心要点：'
    ''
    '- 个人开发的免费工具，**与腾讯公司及《三角洲行动》官方无任何关系**。'
    '- 会修改注册表、电源计划、系统服务等系统级设置；改动前自动备份，可点「还原设置」回退，但还原不保证 100% 成功。'
    '- 优化效果因机器而异，不做任何承诺；部分项有明确副作用，勾选前请读每项说明。'
    '- 没有代码签名证书，SmartScreen 与杀毒软件可能报警，这是必然结果。'
    '- 同意后会发送匿名使用统计：随机安装标识、版本、Windows / CPU / 真实 GPU / 内存 / 设备类型，以及启动、优化、还原和游戏中 120 秒性能采样的汇总结果（FPS、1% Low、GPU 占用率、温度、功耗）；配置只上传未使用/轻量/均衡/深度四档，不发送具体勾选项、自存方案名称、用户名、机器名、SID、游戏路径、注册表内容或逐帧数据。'
    '- 作者不对使用本工具导致的任何损失负责，使用前请自行备份重要数据。'
    ''
    '完整声明见项目根目录的 DISCLAIMER.md。'
  ) -join "`n"
}

# 极简 Markdown 渲染：只处理标题/加粗/列表/分隔线四种，够用且不引第三方库
function Add-MdInlines([Windows.Controls.TextBlock]$Block, [string]$Text) {
  $parts = $Text -split '\*\*'
  for ($i = 0; $i -lt $parts.Count; $i++) {
    if (-not $parts[$i]) { continue }
    $run = New-Object Windows.Documents.Run $parts[$i]
    # 按 ** 切开后，奇数段就是被包起来的部分
    if ($i % 2 -eq 1) { $run.FontWeight = 'Bold'; $run.Foreground = New-Brush $script:C.TextPri }
    $Block.Inlines.Add($run)
  }
}

function Build-MdPanel([string]$Md) {
  $sp = New-Object Windows.Controls.StackPanel
  foreach ($raw in ($Md -split "`r?`n")) {
    $line = $raw.TrimEnd()
    if ($line -match '^#\s+(.*)$') { continue }   # 一级标题即窗口标题，不重复显示
    if ($line -match '^##\s+(.*)$') {
      $t = New-Text $Matches[1] $script:C.Green 14
      $t.FontWeight = 'Bold'
      $t.Margin = New-Object Windows.Thickness 0, 14, 0, 5
      $sp.Children.Add($t) | Out-Null
      continue
    }
    if ($line -match '^---+$') {
      $b = New-Object Windows.Controls.Border
      $b.Height = 1
      $b.Background = New-Brush $script:C.Line
      $b.Margin = New-Object Windows.Thickness 0, 12, 0, 10
      $sp.Children.Add($b) | Out-Null
      continue
    }
    if (-not $line.Trim()) { continue }
    $isLi = ($line -match '^[-*]\s+(.*)$')
    $body = $(if ($isLi) { $Matches[1] } else { $line })
    $t = New-WrapText '' $script:C.TextSec 12
    $t.LineHeight = 20
    if ($isLi) {
      $t.Margin = New-Object Windows.Thickness 14, 2, 0, 2
      $t.Inlines.Add((New-Object Windows.Documents.Run '· '))
    } else {
      $t.Margin = New-Object Windows.Thickness 0, 4, 0, 4
    }
    Add-MdInlines $t $body
    $sp.Children.Add($t) | Out-Null
  }
  $sp
}

# 退出调用单独包一层：验证脚本可替换成 mock 走完「不同意」的完整链路而不真的退掉测试进程
function Invoke-AppExit { [Environment]::Exit(0) }

# 构建与弹出拆开：离屏渲染只需要构建结果，不必真的走模态
function Build-DisclaimerDialog([bool]$ReadOnly) {
  $dxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="620" Height="640" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Border x:Name="DlgTitle" Grid.Row="0" Background="#FF0D1417" BorderBrush="#FF1B2E28"
            BorderThickness="0,0,0,1" Padding="14,11">
      <StackPanel Orientation="Horizontal">
        <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF00E884" VerticalAlignment="Center"/>
        <TextBlock Text="使用前必读" Foreground="#FFFFFFFF" FontSize="15" FontWeight="Bold"
                   Margin="11,0,0,0" VerticalAlignment="Center"/>
        <TextBlock Text="DISCLAIMER" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="10,3,0,0"/>
      </StackPanel>
    </Border>
    <Border Grid.Row="1" Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,12,14,0">
      <ScrollViewer x:Name="Scroller" VerticalScrollBarVisibility="Auto" Padding="16,12,16,14">
        <StackPanel x:Name="Body"/>
      </ScrollViewer>
    </Border>
    <TextBlock x:Name="HintTxt" Grid.Row="2" Text="请滚动到底部阅读完整内容后再选择。"
               Foreground="#FFE5C46A" FontSize="11" Margin="16,8,16,0"/>
    <Grid Grid.Row="3" Margin="14,10,14,14">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <Button x:Name="AgreeBtn" Grid.Column="1" MinWidth="126" Height="34" IsEnabled="False"
              Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
                    Data="M 0.05,0 L 1,0 L 1,0.8 L 0.95,1 L 0,1 L 0,0.2 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bg" Property="Fill" Value="#FF1E3A30"/>
                <Setter Property="Foreground" Value="#FF6B7A73"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="AgreeTxt" Text="同意并继续"/>
      </Button>
      <Button x:Name="DeclineBtn" Grid.Column="2" MinWidth="112" Height="34"
              Foreground="#FF00E884" Margin="10,0,0,0">
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
        <TextBlock x:Name="DeclineTxt" Text="不同意，退出"/>
      </Button>
    </Grid>
  </Grid>
</Window>
'@
  $dlg = [Windows.Markup.XamlReader]::Parse($dxaml)
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $dlg.FindName('Body').Children.Add((Build-MdPanel (Get-DisclaimerText))) | Out-Null
  # 重看模式没有「再同意一次」的语义：只留一个关闭按钮，且不需要滚到底
  if ($ReadOnly) {
    $dlg.FindName('AgreeBtn').Visibility = 'Collapsed'
    $dlg.FindName('DeclineTxt').Text = '关闭'
    $dlg.FindName('HintTxt').Visibility = 'Collapsed'
  }
  $dlg
}

# 构建 + 挂事件（不弹）：拆出来供离屏验证走完整交互，弹窗是 ShowDialog 那一步的事
function Initialize-DisclaimerDialog([bool]$ReadOnly) {
  $script:DcDlg = Build-DisclaimerDialog $ReadOnly
  $script:DcUi = @{}
  foreach ($n in 'DlgTitle','Scroller','AgreeBtn','HintTxt','DeclineBtn') { $script:DcUi[$n] = $script:DcDlg.FindName($n) }
  $script:DcDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:DcDlg.DragMove() })
  if (-not $ReadOnly) {
    $script:DcUi.Scroller.Add_ScrollChanged({
      # 内容比视口还短时永远滚不到「底」，此时直接放行；余量 4px 容忍取整误差
      $sv = $script:DcUi.Scroller
      if ($sv.ScrollableHeight -le 0 -or ($sv.VerticalOffset + $sv.ViewportHeight) -ge ($sv.ExtentHeight - 4)) {
        $script:DcUi.AgreeBtn.IsEnabled = $true
        $script:DcUi.HintTxt.Text = '已读完，可以选择了。'
        $script:DcUi.HintTxt.Foreground = New-Brush $script:C.TextMut
      }
    })
    $script:DcUi.AgreeBtn.Add_Click({ $script:DcDlg.DialogResult = $true })
  }
  $script:DcUi.DeclineBtn.Add_Click({ $script:DcDlg.DialogResult = $false })
  $script:DcDlg
}

# 首次启动的门控：同意才返回 $true。滚到底才放开「同意」——目的是让人至少划一遍
function Show-DisclaimerDialog([switch]$ReadOnly) {
  $dlg = Initialize-DisclaimerDialog ([bool]$ReadOnly)
  $ok = [bool]$dlg.ShowDialog()
  if ($ReadOnly) { return $true }
  if ($ok) { Set-DisclaimerAccepted }
  $ok
}

# ---------- 匿名使用统计（同意声明后异步发送，不阻塞主界面） ----------

$script:TelemetryUploadUrl = 'https://df.ltz88.cn/report/telemetry'
$script:TelemetryJobs = New-Object System.Collections.ArrayList

function Get-TelemetryInstallId {
  $dir = Join-Path $script:RootDir 'config'
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $path = Join-Path $dir 'telemetry.json'
  try {
    if (Test-Path -LiteralPath $path) {
      $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($cfg.Enabled -eq $false) { return $null }
      if ("$($cfg.InstallId)" -match '^[0-9a-fA-F-]{32,64}$') { return "$($cfg.InstallId)" }
    }
  } catch {}
  $id = [guid]::NewGuid().ToString()
  $cfg = [ordered]@{ Enabled = $true; InstallId = $id; CreatedAt = (Get-Date).ToUniversalTime().ToString('o'); ConfigTier = 'baseline' }
  [IO.File]::WriteAllText($path, ($cfg | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
  $id
}

# 只记录粗粒度强度，不记录具体勾选项、自存方案名称或方案内容。
# 同一台匿名设备可据此把优化前后的性能会话配对，避免按每个人的独特配置拆分。
function Get-TelemetryConfigTier {
  try {
    $path = Join-Path $script:RootDir 'config\telemetry.json'
    if (-not (Test-Path -LiteralPath $path)) { return 'baseline' }
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $tier = "$($cfg.ConfigTier)".ToLowerInvariant()
    if ($tier -in 'baseline','light','balanced','full') { return $tier }
  } catch {}
  'baseline'
}

function Set-TelemetryConfigTier([string]$Tier, [switch]$Force) {
  if ($Tier -notin 'baseline','light','balanced','full') { return }
  try {
    $dir = Join-Path $script:RootDir 'config'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $path = Join-Path $dir 'telemetry.json'
    $enabled = $true
    $installId = [guid]::NewGuid().ToString()
    $createdAt = (Get-Date).ToUniversalTime().ToString('o')
    $current = 'baseline'
    if (Test-Path -LiteralPath $path) {
      $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($cfg.Enabled -eq $false) { $enabled = $false }
      if ("$($cfg.InstallId)" -match '^[0-9a-fA-F-]{32,64}$') { $installId = "$($cfg.InstallId)" }
      if ("$($cfg.CreatedAt)") { $createdAt = "$($cfg.CreatedAt)" }
      if ("$($cfg.ConfigTier)".ToLowerInvariant() -in 'baseline','light','balanced','full') {
        $current = "$($cfg.ConfigTier)".ToLowerInvariant()
      }
    }
    $rank = @{ baseline = 0; light = 1; balanced = 2; full = 3 }
    if (-not $Force -and $rank[$current] -gt $rank[$Tier]) { $Tier = $current }
    $out = [ordered]@{ Enabled = $enabled; InstallId = $installId; CreatedAt = $createdAt; ConfigTier = $Tier }
    [IO.File]::WriteAllText($path, ($out | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
  } catch {}
}

function Get-SelectedTelemetryConfigTier([int]$SelectedCount) {
  if ($ui.PresetBox -and $ui.PresetBox.SelectedIndex -ge 0 -and
      $ui.PresetBox.SelectedIndex -lt $script:PresetList.Count) {
    $preset = $script:PresetList[$ui.PresetBox.SelectedIndex]
    switch ("$($preset.Id)") {
      'main' { return 'full' }
      'balanced' { return 'balanced' }
      'safe-only' { return 'light' }
      default { $SelectedCount = @($preset.Items).Count }
    }
  }
  if ($SelectedCount -ge 21) { return 'full' }
  if ($SelectedCount -ge 10) { return 'balanced' }
  if ($SelectedCount -ge 1) { return 'light' }
  'baseline'
}

function Clear-CompletedTelemetryJobs {
  foreach ($job in @($script:TelemetryJobs)) {
    if (-not $job.Async.IsCompleted) { continue }
    try { $job.PowerShell.EndInvoke($job.Async) | Out-Null } catch {}
    try { $job.PowerShell.Dispose() } catch {}
    $script:TelemetryJobs.Remove($job) | Out-Null
  }
}

function Send-AnonymousTelemetry([string]$Event, $Hw, [int]$Ok = 0, [int]$Failed = 0) {
  try {
    if (-not $Hw -or $Event -notin 'launch','apply','restore') { return }
    $installId = Get-TelemetryInstallId
    if (-not $installId) { return }
    Clear-CompletedTelemetryJobs
    $payload = [ordered]@{
      installId = $installId
      event      = $Event
      version    = $script:GuiVersion
      os         = "$($Hw.OS)"
      build      = "$($Hw.Build)"
      cpu        = "$($Hw.CPU)"
      gpuVendor  = "$($Hw.MainGpuVendor)"
      gpuModel   = "$($Hw.MainGpuName)"
      gpuModelVerified = [bool]$Hw.MainGpuNameVerified
      ramGb      = [double]$Hw.RamGB
      deviceType = $(if ($Hw.IsLaptop) { 'laptop' } else { 'desktop' })
      ok         = [math]::Max(0, $Ok)
      failed     = [math]::Max(0, $Failed)
    }
    $body = $payload | ConvertTo-Json -Compress
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($Url, $Body)
      try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
        Invoke-WebRequest -Uri $Url -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8' `
          -TimeoutSec 8 -UseBasicParsing | Out-Null
      } catch {}
    }).AddArgument($script:TelemetryUploadUrl).AddArgument($body)
    $async = $ps.BeginInvoke()
    [void]$script:TelemetryJobs.Add([pscustomobject]@{ PowerShell = $ps; Async = $async })
  } catch {}
}

# ---------- 游戏性能记录（一次会话只采样一段，不常驻逐帧记录） ----------

$script:PerformanceJobs = New-Object System.Collections.ArrayList
$script:MonitoredGamePids = @{}
$script:PerformanceSampleSeconds = 120
$script:PerformanceWarmupSeconds = 20

function Start-GamePerformanceCapture([int]$GamePid, $Hw) {
  if ($GamePid -le 0 -or $script:MonitoredGamePids.ContainsKey($GamePid)) { return }
  $presentMon = Join-Path $script:RootDir 'tools\PresentMon.exe'
  if (-not (Test-Path -LiteralPath $presentMon)) {
    Write-Log '性能记录未启动：缺少 tools\PresentMon.exe。'
    return
  }
  $script:MonitoredGamePids[$GamePid] = $true
  $installId = Get-TelemetryInstallId
  $configTier = Get-TelemetryConfigTier
  $sessionFile = Join-Path $script:RootDir 'config\performance-sessions.json'
  $ps = [PowerShell]::Create()
  [void]$ps.AddScript({
    param($GamePid, $PresentMon, $SessionFile, $UploadUrl, $InstallId, $Version,
          $GpuVendor, $GpuModel, $GpuVerified, $ConfigTier, $WarmupSeconds, $SampleSeconds)
    $ErrorActionPreference = 'SilentlyContinue'

    function Get-Number([object]$Value) {
      $n = 0.0
      if ([double]::TryParse("$Value", [Globalization.NumberStyles]::Float,
          [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
      $null
    }
    function Get-Average($Values) {
      $clean = @($Values | Where-Object { $null -ne $_ })
      if (-not $clean.Count) { return 0.0 }
      [math]::Round(($clean | Measure-Object -Average).Average, 1)
    }
    function Get-Maximum($Values) {
      $clean = @($Values | Where-Object { $null -ne $_ })
      if (-not $clean.Count) { return 0.0 }
      [math]::Round(($clean | Measure-Object -Maximum).Maximum, 1)
    }

    # 避开启动加载期；若游戏提前退出就不生成空会话。
    for ($i = 0; $i -lt $WarmupSeconds; $i++) {
      if (-not (Get-Process -Id $GamePid -ErrorAction SilentlyContinue)) { return }
      Start-Sleep -Seconds 1
    }

    $tmp = Join-Path $env:TEMP "dfb-presentmon-$GamePid-$([guid]::NewGuid().ToString('N')).csv"
    $pm = Start-Process -FilePath $PresentMon -WindowStyle Hidden -PassThru -ArgumentList @(
      '--process_id', "$GamePid", '--output_file', "`"$tmp`"", '--timed', "$SampleSeconds",
      '--terminate_after_timed', '--terminate_on_proc_exit', '--no_console_stats',
      '--session_name', "DFB-$GamePid")

    $util = @(); $temp = @(); $power = @()
    $started = Get-Date
    while ($pm -and -not $pm.HasExited -and ((Get-Date) - $started).TotalSeconds -lt ($SampleSeconds + 15)) {
      if (-not (Get-Process -Id $GamePid -ErrorAction SilentlyContinue)) { break }
      $sampled = $false
      if ($GpuVendor -eq 'NVIDIA' -and (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue)) {
        $raw = @(& nvidia-smi.exe '--query-gpu=utilization.gpu,temperature.gpu,power.draw' '--format=csv,noheader,nounits' 2>$null)
        if ($LASTEXITCODE -eq 0 -and $raw.Count) {
          $parts = @("$($raw[0])" -split ',' | ForEach-Object { $_.Trim() })
          if ($parts.Count -ge 3) {
            $u = Get-Number $parts[0]; $t = Get-Number $parts[1]; $w = Get-Number $parts[2]
            if ($null -ne $u) { $util += $u; $sampled = $true }
            if ($null -ne $t) { $temp += $t }
            if ($null -ne $w) { $power += $w }
          }
        }
      }
      # AMD / Intel 或 nvidia-smi 不可用时，退回 Windows GPU Engine 计数器。
      if (-not $sampled) {
        $counters = @(Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples |
          Where-Object { $_.InstanceName -match "pid_$($GamePid)_" -and $_.InstanceName -match 'engtype_3D' }
        if ($counters.Count) {
          $sum = [math]::Min(100.0, [double](($counters | Measure-Object CookedValue -Sum).Sum))
          $util += $sum
        }
      }
      Start-Sleep -Seconds 2
      try { $pm.Refresh() } catch {}
    }
    if ($pm -and -not $pm.HasExited) { try { $pm.Kill() } catch {} }
    if ($pm) { try { $pm.WaitForExit(5000) | Out-Null } catch {} }

    $frameMs = New-Object 'System.Collections.Generic.List[double]'
    if (Test-Path -LiteralPath $tmp) {
      try {
        foreach ($row in @(Import-Csv -LiteralPath $tmp)) {
          $ms = Get-Number $row.MsBetweenPresents
          if ($null -ne $ms -and $ms -gt 0 -and $ms -le 1000) { $frameMs.Add([double]$ms) }
        }
      } catch {}
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
    $avgFps = 0.0; $fps1Low = 0.0
    if ($frameMs.Count -ge 30) {
      $avgMs = ($frameMs | Measure-Object -Average).Average
      if ($avgMs -gt 0) { $avgFps = [math]::Round(1000.0 / $avgMs, 1) }
      $fps = @($frameMs | ForEach-Object { 1000.0 / $_ } | Sort-Object)
      $idx = [math]::Max(0, [math]::Floor(($fps.Count - 1) * 0.01))
      $fps1Low = [math]::Round($fps[$idx], 1)
    }

    $session = [ordered]@{
      recordedAt = (Get-Date).ToUniversalTime().ToString('o')
      durationSec = [math]::Min($SampleSeconds, [math]::Round(((Get-Date) - $started).TotalSeconds))
      gpuModel = "$GpuModel"
      configTier = "$ConfigTier"
      avgFps = $avgFps; fps1Low = $fps1Low
      gpuUtilAvg = Get-Average $util; gpuUtilMax = Get-Maximum $util
      gpuTempAvg = Get-Average $temp; gpuTempMax = Get-Maximum $temp
      gpuPowerAvg = Get-Average $power; gpuPowerMax = Get-Maximum $power
    }
    if ($session.avgFps -le 0 -and $session.gpuUtilAvg -le 0) { return }

    # 本地只保留最近 50 段汇总，诊断报告可直接带上；不保留逐帧 CSV。
    try {
      $dir = Split-Path -Parent $SessionFile
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      $old = @()
      if (Test-Path -LiteralPath $SessionFile) { $old = @(Get-Content -LiteralPath $SessionFile -Raw -Encoding UTF8 | ConvertFrom-Json) }
      $all = @($old) + [pscustomobject]$session
      if ($all.Count -gt 50) { $all = @($all | Select-Object -Last 50) }
      [IO.File]::WriteAllText($SessionFile, ($all | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($true)))
    } catch {}

    # 真实型号未通过驱动验证时只留本地，不把可能仍受 DeviceDesc 伪装影响的名称送上榜。
    if ($InstallId -and $GpuVerified) {
      try {
        $payload = [ordered]@{
          installId = $InstallId; event = 'performance'; version = $Version
          gpuVendor = $GpuVendor; gpuModel = $GpuModel; gpuModelVerified = [bool]$GpuVerified
          configTier = $ConfigTier
          durationSec = $session.durationSec; avgFps = $session.avgFps; fps1Low = $session.fps1Low
          gpuUtilAvg = $session.gpuUtilAvg; gpuUtilMax = $session.gpuUtilMax
          gpuTempAvg = $session.gpuTempAvg; gpuTempMax = $session.gpuTempMax
          gpuPowerAvg = $session.gpuPowerAvg; gpuPowerMax = $session.gpuPowerMax
        }
        $body = [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress))
        Invoke-WebRequest -Uri $UploadUrl -Method Post -Body $body -ContentType 'application/json; charset=utf-8' `
          -TimeoutSec 8 -UseBasicParsing | Out-Null
      } catch {}
    }
  })
  foreach ($arg in @($GamePid, $presentMon, $sessionFile, $script:TelemetryUploadUrl, $installId,
                      $script:GuiVersion, "$($Hw.MainGpuVendor)", "$($Hw.MainGpuName)",
                      [bool]$Hw.MainGpuNameVerified, $configTier, $script:PerformanceWarmupSeconds,
                      $script:PerformanceSampleSeconds)) {
    [void]$ps.AddArgument($arg)
  }
  $async = $ps.BeginInvoke()
  [void]$script:PerformanceJobs.Add([pscustomobject]@{ PowerShell = $ps; Async = $async; Pid = $GamePid })
  Write-Log "检测到游戏进程 PID $GamePid：将在启动稳定后记录 120 秒 FPS / GPU 性能汇总。"
}

function Poll-GamePerformanceCapture {
  foreach ($job in @($script:PerformanceJobs)) {
    if (-not $job.Async.IsCompleted) { continue }
    try { $job.PowerShell.EndInvoke($job.Async) | Out-Null } catch {}
    try { $job.PowerShell.Dispose() } catch {}
    $script:PerformanceJobs.Remove($job) | Out-Null
    Write-Log "游戏性能记录已完成（PID $($job.Pid)），汇总已保存到本地并按隐私设置匿名上报。"
  }
  if (-not $script:TargetExe) { return }
  $name = [IO.Path]::GetFileNameWithoutExtension($script:TargetExe)
  foreach ($proc in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
    Start-GamePerformanceCapture $proc.Id $script:HardwareInfo
  }
}

# ---------- 诊断报告（本地组装 + 脱敏 + 用户确认后上传） ----------

$script:ReportUploadUrl = 'https://df.ltz88.cn/report/upload'
$script:ReportMaxBytes = 256KB

# 脱敏：路径里的用户名、机器名、账户名一律替换。目录结构保留——排查问题要看得出
# 游戏装在哪层目录，但没必要知道机器主人叫什么
function Protect-ReportText([string]$Text) {
  if (-not $Text) { return $Text }
  $t = $Text -replace '(?i)([A-Za-z]:\\Users\\)[^\\\r\n"'']+', '${1}<user>'
  $t = $t -replace '(?i)(\\Users\\)[^\\\r\n"'']+', '${1}<user>'
  foreach ($pair in @(@($env:USERNAME, '<user>'), @($env:COMPUTERNAME, '<pc>'), @($env:USERDOMAIN, '<domain>'))) {
    if ("$($pair[0])".Length -ge 2) { $t = $t -replace [regex]::Escape($pair[0]), $pair[1] }
  }
  $t
}

# 报告只放排查需要的：硬件 + 各优化项当前状态 + 运行日志 + 版本号 + 最近备份的项目名。
# 绝不带备份 JSON 原文——那里面是注册表原值，外传没有意义
function New-DiagnosticReport {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("DeltaForceBooster 诊断报告")
  $lines.Add("生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
  $lines.Add("界面版本：v$script:GuiVersion")
  $lines.Add('')

  $lines.Add('== 硬件与系统 ==')
  try {
    $hw = Get-HardwareInfo
    $lines.Add("系统：$($hw.OS)（Build $($hw.Build)）")
    $lines.Add("CPU：$($hw.CPU)（$($hw.Cores) 核 $($hw.Threads) 线程）")
    $lines.Add("内存：$($hw.RamGB) GB")
    foreach ($g in $hw.Gpus) {
      $lines.Add("显卡（真实）：$($g.Name)（$($g.Vendor)，驱动 $($g.Driver)）")
      if ($g.ReportedName -and $g.ReportedName -ne $g.Name) { $lines.Add("     系统当前伪装上报：$($g.ReportedName)") }
    }
    $lines.Add("机型：$(if ($hw.IsLaptop) { '笔记本' } else { '台式机' })")
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 游戏路径 ==')
  $lines.Add($(if ($script:TargetExe) { "$script:TargetExe" } else { '未定位' }))
  $lines.Add('')

  $lines.Add('== 最近游戏性能记录 ==')
  try {
    $perfFile = Join-Path $script:RootDir 'config\performance-sessions.json'
    if (-not (Test-Path -LiteralPath $perfFile)) { $lines.Add('（暂无记录；v0.19.0 起在游戏启动稳定后自动采样）') }
    else {
      $sessions = @(Get-Content -LiteralPath $perfFile -Raw -Encoding UTF8 | ConvertFrom-Json | Select-Object -Last 5)
      foreach ($s in $sessions) {
        $lines.Add("$($s.recordedAt)｜$($s.gpuModel)｜$($s.durationSec)s｜平均 $($s.avgFps) FPS｜1% Low $($s.fps1Low) FPS")
        $lines.Add("     GPU 占用 $($s.gpuUtilAvg)% / 峰值 $($s.gpuUtilMax)%｜温度 $($s.gpuTempAvg)°C / 峰值 $($s.gpuTempMax)°C｜功耗 $($s.gpuPowerAvg)W / 峰值 $($s.gpuPowerMax)W")
      }
    }
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 优化项状态 ==')
  try {
    foreach ($it in @(Get-OptItems $script:TargetExe $script:SelectedGpuSpoofModel)) {
      $st = Get-ItemState $it
      $mark = $(if ($st.Optimized -eq $true) { '[√]' } elseif ($st.Optimized -eq $false) { '[×]' } else { '[?]' })
      $lines.Add("$mark $($it.Id) — $($it.Name)")
      $lines.Add("     当前：$($st.Current)")
    }
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 最近一次备份的项目 ==')
  try {
    $bak = Get-ChildItem (Join-Path $script:RootDir 'backup') -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue |
           Sort-Object Name -Descending | Select-Object -First 1
    if (-not $bak) { $lines.Add('（无备份）') }
    else {
      # 只列项目名，不带任何原值
      $b = Get-Content -LiteralPath $bak.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      $lines.Add("文件：$($bak.Name)（$(@($b.Ops).Count) 项，$($b.Time)）")
      foreach ($op in @($b.Ops)) { $lines.Add("  - $(Get-RestoreOpLabel $op)") }
    }
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 运行日志 ==')
  $lines.Add($(if ($ui.LogBox.Text) { $ui.LogBox.Text } else { '（空）' }))

  $txt = Protect-ReportText (($lines -join "`r`n"))
  # 上限按字节算：中文一个字三字节，按字符数截会超
  $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
  if ($bytes.Length -gt $script:ReportMaxBytes) {
    $keep = [Text.Encoding]::UTF8.GetString($bytes, 0, $script:ReportMaxBytes - 200)
    $txt = $keep + "`r`n`r`n【注意】报告超过 256KB 上限，以上内容已被截断。"
  }
  $txt
}

# 真正发请求的唯一出口：验证时整体替换成桩，绝不往服务器发测试数据
function Invoke-ReportUpload([string]$Body) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
  $r = Invoke-WebRequest -Uri $script:ReportUploadUrl -Method Post -Body $bytes `
        -ContentType 'text/plain; charset=utf-8' -TimeoutSec 30 -UseBasicParsing
  ($r.Content | ConvertFrom-Json).code
}

# ---------- 显卡指引对话框（驱动层设置 + 控制面板入口） ----------

# 启动控制面板的唯一出口。appx 没有可直接执行的 exe 路径，只能经 shell:appsFolder
function Open-GpuPanel($App) {
  if ($App.Kind -eq 'appx') { Start-Process 'explorer.exe' "shell:appsFolder\$($App.Target)" }
  else { Start-Process -FilePath $App.Target }
}

function Build-GpuGuideDialog($Hw) {
  $gxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="520" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="显卡指引" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="GPU DRIVER GUIDE" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <Border Background="#FF0E2A21" BorderBrush="#FF17603F" BorderThickness="1" Margin="14,12,14,0" Padding="10,7">
      <TextBlock x:Name="BannerTxt" Text="" Foreground="#FF00E884" FontSize="12" FontWeight="Bold" TextWrapping="Wrap"/>
    </Border>
    <StackPanel x:Name="AppPanel" Margin="14,10,14,0"/>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,10,14,12">
      <ScrollViewer MaxHeight="300" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="MsgTxt" Text="" Foreground="#FF9AA5A0" FontSize="12" LineHeight="19"
                   TextWrapping="Wrap" Padding="12,9"/>
      </ScrollViewer>
    </Border>
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
  $dlg = [Windows.Markup.XamlReader]::Parse($gxaml)
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $banner = "检测到你的显卡：$($Hw.MainGpuName)"
  if (@($Hw.Gpus).Count -gt 1) {
    $allGpuNames = @($Hw.Gpus | ForEach-Object { $_.Name }) -join ' + '
    $banner = "检测到双显卡：$allGpuNames`n以下按独显 $($Hw.MainGpuName) 给出"
  }
  $dlg.FindName('BannerTxt').Text = $banner
  $dlg.FindName('MsgTxt').Text = Get-GpuGuideText $Hw.MainGpuVendor $Hw.MainGpuName $Hw.IsLaptop

  $panel = $dlg.FindName('AppPanel')
  foreach ($app in @(Get-GpuPanelApps $Hw.MainGpuVendor)) {
    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.Margin = New-Object Windows.Thickness 0, 0, 0, 6
    if ($app.Installed) {
      $b = New-Object Windows.Controls.Button
      $b.Style = $window.FindResource('Ghost')
      $b.Content = "打开 $($app.Name)"
      $b.FontSize = 11
      $b.Height = 26
      $b.MinWidth = 168
      # 循环里挂的处理器不能闭包引用循环变量，一律从 sender.Tag 取
      $b.Tag = [pscustomobject]@{ Kind = $app.Kind; Target = $app.Target; Name = $app.Name }
      $b.Add_Click({
        try { Open-GpuPanel $this.Tag; Write-Log "已打开 $($this.Tag.Name)。" }
        catch { Write-Log "打开 $($this.Tag.Name) 失败：$($_.Exception.Message)" }
      })
      $row.Children.Add($b) | Out-Null
    } else {
      # 缺失时明确告诉用户下一步点哪里；按钮直接打开对应厂商的官方下载页
      $t = New-WrapText "未检测到 $($app.Name)：$($app.Missing)。请点击右侧「下载 $($app.Name)」打开官网，安装完成后重新打开本工具。" $script:C.TextMut 11
      $t.MaxWidth = 300
      $t.Margin = New-Object Windows.Thickness 0, 0, 8, 0
      $row.Children.Add($t) | Out-Null
      $b = New-Object Windows.Controls.Button
      $b.Style = $window.FindResource('Ghost')
      $b.Content = "下载 $($app.Name)"
      $b.FontSize = 11
      $b.Height = 26
      $b.Tag = "$($app.Download)"
      $b.ToolTip = "$($app.Download)"
      $b.Add_Click({ Open-HelpLink "$($this.Tag)" })
      $row.Children.Add($b) | Out-Null
    }
    $panel.Children.Add($row) | Out-Null
  }
  $dlg
}

function Show-GpuGuideDialog($Hw) {
  $script:GgDlg = Build-GpuGuideDialog $Hw
  $script:GgDlg.Owner = $window
  $script:GgDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:GgDlg.DragMove() })
  $script:GgDlg.FindName('OkBtn').Add_Click({ $script:GgDlg.DialogResult = $true })
  [void]$script:GgDlg.ShowDialog()
}

# ---------- 标签页切换与执行态 ----------

$script:Busy = $false

function Select-Tab([string]$Which) {
  foreach ($t in @(@('opt', 'TabOptBtn', 'OptPage'), @('ref', 'TabRefBtn', 'RefPage'), @('log', 'TabLogBtn', 'LogPage'))) {
    $on = ($Which -eq $t[0])
    $ui[$t[1]].Tag = $(if ($on) { 'on' } else { '' })
    $ui[$t[2]].Visibility = $(if ($on) { 'Visible' } else { 'Collapsed' })
  }
  # 执行按钮只属于优化页，别让人以为参考设置或日志能「执行」
  $ui.ActionRow.Visibility = $(if ($Which -eq 'opt') { 'Visible' } else { 'Collapsed' })
  # 每次切入都重建：数据文件可能是界面启动之后才生成的
  if ($Which -eq 'ref') { Update-StreamerPage }
  # 看过就不用再提示了
  if ($Which -eq 'log') { Set-LogBadge 0 }
}

# 日志页角标：日志不在眼前了，出了失败/体检问题得有个信号。0 即清除
function Set-LogBadge([int]$Count) {
  $ui.LogBadgeTxt.Text = $(if ($Count -gt 99) { '99+' } else { "$Count" })
  $ui.LogBadge.Visibility = $(if ($Count -gt 0) { 'Visible' } else { 'Collapsed' })
}

function Set-BusyState([bool]$On) {
  # 执行期间禁用一切入口防重复点击；窗口关闭由 CloseBtn 与主窗口 Closing 双重拦截
  $script:Busy = $On
  foreach ($n in 'ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','CheckUpdBtn','ReportBtn','BrowseBtn',
                 'SavePresetBtn','DelPresetBtn','PresetBox','TabOptBtn','TabRefBtn','UpdateBtn') {
    if ($ui[$n]) { $ui[$n].IsEnabled = -not $On }
  }
  # 更新恰好在执行优化/还原时被检测到：先不打断系统修改，收尾后立即补弹详情
  if (-not $On -and $script:UpdateInfo -and
      "$script:UpdatePromptedVersion" -ne "$($script:UpdateInfo.Version)") {
    [void]$window.Dispatcher.BeginInvoke([action]{ Show-DetectedUpdateDialog })
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
  # 深色滚动条等共享 Chrome：独立 Window 不继承主窗口资源，必须逐个挂（实机反馈）
  $script:CfmDlg.Resources.MergedDictionaries.Add($script:ThemeRes)
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
  $script:RbDlg.Resources.MergedDictionaries.Add($script:ThemeRes)
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
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
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

# 安装器日志：静默安装出问题时这是唯一的现场（主程序此刻已经退了）
$script:SetupLogPath = Join-Path $script:RootDir 'config\update-setup.log'

# 真正启动安装器的唯一出口：验证时整体替换成桩，绝不真的覆盖自身。
# /waitpid 让安装器等本进程退出后再覆盖文件，/runafter 让它装完自启新版；
# 装回 $script:RootDir 而不是默认位置——用户可能把程序装在任意目录
function Invoke-BoosterSetupRun([string]$SetupFile, [string]$TargetDir, [string]$LogFile) {
  Start-Process -FilePath $SetupFile -PassThru -ArgumentList @(
    '/silent', "/dir=`"$TargetDir`"", "/waitpid=$PID", '/runafter', "/log=`"$LogFile`"")
}

# 安装阶段的不确定进度：安装在另一个进程里跑，拿不到百分比，只能转圈
function Start-UpdInstallSpinner {
  $script:UpdUi.InstPanel.Visibility = 'Visible'
  $anim = New-Object Windows.Media.Animation.DoubleAnimation 0, 360, ([TimeSpan]::FromSeconds(1.1))
  $anim.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
  $script:UpdUi.SpinRot.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $anim)
  # 安装期间不许再点任何东西，也不许关窗——关了也停不下已经起来的安装器，只会让人困惑
  foreach ($n in 'SkipChk','UpdBtn','GoBtn','LaterBtn','CancelDlBtn') { $script:UpdUi[$n].Visibility = 'Collapsed' }
  $script:UpdInstalling = $true
  Set-BusyState $true
}

function Stop-UpdInstallSpinner {
  $script:UpdInstalling = $false
  $script:UpdUi.SpinRot.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $null)
  $script:UpdUi.InstPanel.Visibility = 'Collapsed'
  Set-BusyState $false
}

# 更新对话框的按钮态复位：取消下载 / 下载失败后回到可再次操作的状态。
# 「立即更新」只在清单过了安检（CanInline）时出现，降级入口「前往下载」永远可用。
function Reset-UpdDialogButtons {
  $script:UpdUi.DlPanel.Visibility = 'Collapsed'
  $script:UpdUi.CancelDlBtn.Visibility = 'Collapsed'
  $script:UpdUi.SkipChk.Visibility = $(if ($script:UpdDlgInfo.Mandatory) { 'Collapsed' } else { 'Visible' })
  $script:UpdUi.UpdBtn.Visibility = $(if ($script:UpdDlgInfo.CanInline) { 'Visible' } else { 'Collapsed' })
  $script:UpdUi.GoBtn.Visibility = 'Visible'
  $script:UpdUi.LaterBtn.Visibility = $(if ($script:UpdDlgInfo.Mandatory) { 'Collapsed' } else { 'Visible' })
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
    <!-- 内置更新说明：走安装器覆盖升级，覆盖安装保护会保住配置与备份 -->
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
    <!-- 安装阶段：进度不可知（安装器在另一个进程里跑），只给转圈 + 一句话 -->
    <StackPanel x:Name="InstPanel" Visibility="Collapsed" Orientation="Horizontal" Margin="14,2,14,12">
      <Grid Width="20" Height="20" RenderTransformOrigin="0.5,0.5" VerticalAlignment="Center">
        <Grid.RenderTransform>
          <RotateTransform x:Name="SpinRot" Angle="0"/>
        </Grid.RenderTransform>
        <Ellipse Stroke="#FF1B2E28" StrokeThickness="2.5" Width="18" Height="18"/>
        <Path Stroke="#FF00E884" StrokeThickness="2.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
              Data="M 10,1 A 9,9 0 0 1 19,10"/>
      </Grid>
      <TextBlock x:Name="InstText" Text="正在安装，请稍候…" Foreground="#FF00E884" FontSize="12"
                 VerticalAlignment="Center" Margin="11,0,0,0"/>
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
  $script:UpdDlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $script:UpdDlgInfo = $UpdInfo
  $script:AllowMandatoryDialogClose = $false
  $script:UpdDlg.Owner = $window
  $script:UpdUi = @{}
  foreach ($n in 'DlgTitle','VerText','CurText','NotesText','InlineNote','DlPanel','DlPhaseText','DlSizeText',
                 'DlTrack','DlFill','InstPanel','InstText','SpinRot','ErrPanel','ErrText','SkipChk','UpdBtn','GoBtn','GoTxt',
                 'CancelDlBtn','CancelDlTxt','LaterBtn') {
    $script:UpdUi[$n] = $script:UpdDlg.FindName($n)
  }
  $script:UpdUi.VerText.Text = "新版本 v$($UpdInfo.Version)"
  $script:UpdUi.CurText.Text = "当前 v$($UpdInfo.Current)"
  # 清单由发布脚本写成单行 JSON 时常用字面量 \n 表示换行；显示前统一还原，避免更新
  # 说明里直接露出“\n”字符。
  $notes = ("$($UpdInfo.Notes)" -replace '\\n', "`n").Trim()
  $script:UpdUi.NotesText.Text = $(if ($notes) { $notes } else { '（本次更新没有附带说明）' })
  if ($UpdInfo.Mandatory) {
    $script:UpdUi.SkipChk.Visibility = 'Collapsed'
    $script:UpdUi.LaterBtn.Visibility = 'Collapsed'
    $script:UpdUi.CurText.Text += " · 此版本已停止支持，需升级后继续使用"
  }
  if ($UpdInfo.CanInline) {
    $script:UpdUi.InlineNote.Text = '「立即更新」全程自动：从官方源（df.ltz88.cn）下载 → 校验完整性 → 原地安装到当前目录 → 自动打开新版本，中途不需要你再操作。自存方案 / 备份 / 运行状态不会被覆盖。'
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
      # 用户点「立即更新」时就已经授权了整条链路，这里不再要求他确认第二次：
      # 直接转圈 + 静默安装 + 自启新版（安装只在校验通过后发生，见 updater.ps1 的授权边界）
      Start-UpdInstallSpinner
      $script:UpdUi.DlPanel.Visibility = 'Collapsed'
      try {
        # 安装器要覆盖本程序的文件，必须等本进程退出——把 /waitpid 交给它，
        # 我们启动完立刻自退，等待逻辑放在安装器侧（这边退出后就没人能干活了）
        $proc = Invoke-BoosterSetupRun $st.File $script:RootDir $script:SetupLogPath
        if (-not $proc) { throw '安装程序未能启动' }
        Write-Log "安装程序已启动（PID $($proc.Id)），本程序即将退出，安装完成后新版本会自动打开。"
        # 交棒完成，放行关窗：拦截关窗的守卫是拦用户的，别把自己也拦在里面。
        # 这里用 Close() 而不是设 DialogResult——非模态时后者会抛，且返回值此刻已无意义
        $script:UpdInstalling = $false
        $script:AllowMandatoryDialogClose = $true
        $script:UpdDlg.Close()
        $window.Close()
        # Close 之后进程未必真退（实机反馈旧窗口残留、与安装后的新实例并存）：
        # WPF 宿主里还挂着更新检查的后台 runspace 和嵌套的模态/调度帧，powershell
        # 不会因为窗口关了就结束。安装器已经拉起，这里强制退出兜底
        Invoke-AppExit
      } catch {
        Stop-UpdInstallSpinner
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
    if ($u -match '^https?://') {
      Start-Process $u
      if ($script:UpdDlgInfo.Mandatory) {
        $script:AllowMandatoryDialogClose = $true
        $script:UpdDlg.DialogResult = $true
        $window.Close()
        return
      }
    } else { Write-Log '更新清单里的下载地址不是网页链接，已拦截。'; return }
    $script:UpdDlg.DialogResult = $true
  })
  $script:UpdUi.LaterBtn.Add_Click({ $script:UpdDlg.DialogResult = $false })
  # 安装已经起来了就不许关窗：关了也停不下安装器，只会让用户以为取消了
  $script:UpdDlg.Add_Closing({
    if ($script:UpdInstalling -or ($script:UpdDlgInfo.Mandatory -and -not $script:AllowMandatoryDialogClose)) { $_.Cancel = $true }
  })
  # 下载中途直接关掉对话框：请求后台取消，轮询定时器会等它清理完临时文件再回收
  $script:UpdDlg.Add_Closed({
    if ($script:DlState -and -not $script:DlState.Done) { $script:DlState.Cancel = $true }
  })
  $script:UpdDlg.ShowDialog() | Out-Null
  if (-not $UpdInfo.Mandatory -and $script:UpdUi.SkipChk.IsChecked -and (Get-Command Set-BoosterSkipVersion -ErrorAction SilentlyContinue)) {
    # 返回值必须吞掉：现在函数输出会被调用方接住，落盘结果混进去会把 $skipped 变成数组
    Set-BoosterSkipVersion $UpdInfo.Version | Out-Null
    Write-Log "已设置不再提醒 v$($UpdInfo.Version)。"
    # 返回「用户选择了跳过」：调用方据此把标题栏的更新入口一并收起，语义保持一致
    return $true
  }
  $false
}

# 自动检查发现新版时的统一弹窗出口。同一版本每次程序运行只自动弹一次；用户选了
# 「稍后再说」仍可点标题栏入口重看，勾「不再提醒」则后续启动也不再自动提示。
function Show-DetectedUpdateDialog {
  if (-not $script:UpdateInfo -or $script:Busy -or $script:UpdateDialogOpen) { return }
  $ver = "$($script:UpdateInfo.Version)"
  if (-not $ver -or "$script:UpdatePromptedVersion" -eq $ver) { return }
  $script:UpdatePromptedVersion = $ver
  $script:UpdateDialogOpen = $true
  try {
    if (Show-UpdateDialog $script:UpdateInfo) { $ui.UpdateBtn.Visibility = 'Collapsed' }
  } finally {
    $script:UpdateDialogOpen = $false
  }
}

function Update-ItemList {
  $ui.ItemPanel.Children.Clear()
  $ui.RiskyPanel.Children.Clear()
  # 变量名不能用 $items：引擎被点源进同一作用域，其 [string[]]$Items 参数会把哈希表强制转成字符串
  $optItems = @(Get-OptItems $script:TargetExe $script:SelectedGpuSpoofModel)
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
# 检测到新版会直接弹详情，同时保留标题栏常驻入口供稍后重看。
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
          # 新版本第一次出现就直接弹详情；同一版本本次运行只自动弹一次，标题栏入口常驻
          $isNew = ("$($found.Version)" -ne "$(if ($script:UpdateInfo) { $script:UpdateInfo.Version })")
          $script:UpdateInfo = $found
          $ui.UpdateBtn.ToolTip = "新版本 v$($found.Version) 可用（当前 v$($found.Current)），点击查看详情"
          $ui.UpdateBtn.Visibility = 'Visible'
          if ($isNew) {
            Write-Log "检测到新版本 v$($found.Version)（当前 v$($found.Current)），正在显示更新详情。"
            Show-DetectedUpdateDialog
          }
        }
      } catch {} finally { $script:UpdateJob.Dispose(); $script:UpdateCheckBusy = $false }
    })
    $script:UpdateTimer.Start()
  } catch { $script:UpdateCheckBusy = $false }
}

# 手动检查更新（v0.13，实机诉求）：定时检查是静默的，手动点击必须给出明确结果——
# 已最新 / 发现新版弹详情 / 网络失败提示。只看 Test-BoosterUpdate 的 $null 分不出
# 「已最新」和「拿不到清单」，所以先取清单分辨状态；手动检查带 -IncludeSkipped：
# 用户主动点按钮就是想看结果，「不再提醒此版本」的记录不该拦住他
function Start-ManualUpdateCheck {
  if ($script:ManualCheckBusy) { return }
  if (-not (Get-Command Test-BoosterUpdate -ErrorAction SilentlyContinue)) {
    Show-ConfirmDialog '检查更新' 'CHECK UPDATE' '更新模块（scripts\updater.ps1）缺失，无法检查更新。请重新安装完整版本。' '知道了' -InfoOnly | Out-Null
    return
  }
  $script:ManualCheckBusy = $true
  $ui.CheckUpdBtn.IsEnabled = $false
  $ui.CheckUpdBtn.Content = '检查中…'
  Write-Log '正在检查更新…'
  $ps = [PowerShell]::Create()
  [void]$ps.AddScript({
    param($ModulePath, $Cur, $ManifestUrl)
    try {
      . $ModulePath
      $m = Get-BoosterManifest $ManifestUrl
      if (-not $m) { return [pscustomobject]@{ Status = 'error' } }
      if ((Compare-BoosterVersion "$($m.version)" $Cur) -le 0) { return [pscustomobject]@{ Status = 'latest' } }
      $found = Test-BoosterUpdate -CurrentVersion $Cur -ManifestUrl $ManifestUrl -IncludeSkipped
      if ($found) { return [pscustomobject]@{ Status = 'found'; Info = $found } }
      [pscustomobject]@{ Status = 'latest' }
    } catch { [pscustomobject]@{ Status = 'error' } }
  })
  foreach ($arg in @($script:UpdaterPath, $script:GuiVersion, $script:BoosterManifestUrl)) { [void]$ps.AddArgument($arg) }
  $script:ManualCheckJob = $ps
  $script:ManualCheckAsync = $ps.BeginInvoke()
  $script:ManualCheckTimer = New-Object Windows.Threading.DispatcherTimer
  $script:ManualCheckTimer.Interval = [TimeSpan]::FromMilliseconds(300)
  $script:ManualCheckTimer.Add_Tick({
    if (-not $script:ManualCheckAsync.IsCompleted) { return }
    $script:ManualCheckTimer.Stop()
    $r = $null
    try { $r = @($script:ManualCheckJob.EndInvoke($script:ManualCheckAsync)) | Where-Object { $_ } | Select-Object -First 1 } catch {}
    try { $script:ManualCheckJob.Dispose() } catch {}
    $script:ManualCheckBusy = $false
    $ui.CheckUpdBtn.Content = '检查更新'
    # 恢复可用要看全局忙碌态：万一结果回来时正在执行优化，不能把按钮提前放开
    if (-not $script:Busy) { $ui.CheckUpdBtn.IsEnabled = $true }
    if (-not $r -or $r.Status -eq 'error') {
      Write-Log '检查更新失败：网络不可达或服务器暂时无响应。'
      Show-ConfirmDialog '检查更新' 'CHECK UPDATE' '检查更新失败：网络不可达或服务器暂时无响应，请稍后再试。' '知道了' -InfoOnly | Out-Null
    } elseif ($r.Status -eq 'latest') {
      Write-Log "已是最新版本 v$($script:GuiVersion)。"
      Show-ConfirmDialog '检查更新' 'CHECK UPDATE' "已是最新版本 v$($script:GuiVersion)，无需更新。" '知道了' -InfoOnly | Out-Null
    } else {
      # 发现新版：与定时检查同一收口——点亮标题栏入口，并直接弹更新详情
      $script:UpdateInfo = $r.Info
      $ui.UpdateBtn.ToolTip = "新版本 v$($r.Info.Version) 可用（当前 v$($r.Info.Current)），点击查看详情"
      $ui.UpdateBtn.Visibility = 'Visible'
      Write-Log "检测到新版本 v$($r.Info.Version)（当前 v$($r.Info.Current)）。"
      if (Show-UpdateDialog $script:UpdateInfo) { $ui.UpdateBtn.Visibility = 'Collapsed' }
    }
  })
  $script:ManualCheckTimer.Start()
}

$script:TargetExe = $null
$script:PresetList = @()
$script:ApplyingPreset = $false
$script:SelectedGpuSpoofModel = $null
$script:UpdateInfo = $null
$script:UpdatePromptedVersion = $null
$script:UpdateDialogOpen = $false
$script:HardwareInfo = $null

$window.Add_ContentRendered({
  try {
    $hw = Get-HardwareInfo
    $script:HardwareInfo = $hw
    $ui.HwGrid.Children.Clear()
    $gpu = ($hw.Gpus | Where-Object { $_.Name -eq $hw.MainGpuName } | Select-Object -First 1)
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
    # 启动即默认选中主推方案（实机诉求「进去之后默认直接选择主推全套」）：
    # SelectionChanged 处理器会完成勾选，其中已就绪的项自动跳过不重复勾
    for ($fi = 0; $fi -lt $script:PresetList.Count; $fi++) {
      if ($script:PresetList[$fi].Id -eq 'main') { $ui.PresetBox.SelectedIndex = $fi; break }
    }
    $ui.ScanState.Text = '检测完成'
    Write-Log '检测完成。已默认选中「主推全套」方案，可改选其他方案或手动勾选后点「执行优化」，带 * 的项需要管理员权限。'
    Send-AnonymousTelemetry 'launch' $hw
    Start-UpdateCheck
    # 运行期间定时复查：DispatcherTimer 在 UI 线程触发，真正的网络请求仍在后台 runspace，
    # 静默失败的约定不变——断网/超时都不会打扰主界面
    $script:UpdatePeriodicTimer = New-Object Windows.Threading.DispatcherTimer
    $script:UpdatePeriodicTimer.Interval = [TimeSpan]::FromMinutes($script:UpdateCheckIntervalMinutes)
    $script:UpdatePeriodicTimer.Add_Tick({ Start-UpdateCheck })
    $script:UpdatePeriodicTimer.Start()
    # 软件保持打开时观察游戏进程；每个 PID 只采一次 120 秒汇总，不做永久逐帧录制。
    $script:PerformanceTimer = New-Object Windows.Threading.DispatcherTimer
    $script:PerformanceTimer.Interval = [TimeSpan]::FromSeconds(5)
    $script:PerformanceTimer.Add_Tick({ Poll-GamePerformanceCapture })
    $script:PerformanceTimer.Start()
    Poll-GamePerformanceCapture
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
# 忙碌关窗守卫（真正的防线在 Closing 上）：CloseBtn 只拦自绘按钮，外部程序发的
# WM_CLOSE（如安装器 CloseMainWindow）和 Alt+F4 都不经过它——执行/还原中途被关会
# 留下写了一半的系统改动，必须在 Closing 事件里统一拦截
$window.Add_Closing({
  if ($script:Busy) {
    $_.Cancel = $true
    Write-Log '正在执行优化/还原，请等本轮结束后再关闭。'
  } else {
    if ($script:PerformanceTimer) { $script:PerformanceTimer.Stop() }
  }
})
$ui.CloseBtn.Add_Click({
  if ($script:Busy) { Write-Log '正在执行优化，请等本轮执行结束后再关闭。'; return }
  $window.Close()
})

$ui.TabOptBtn.Add_Click({ Select-Tab 'opt' })
$ui.TabRefBtn.Add_Click({ Select-Tab 'ref' })
$ui.TabLogBtn.Add_Click({ Select-Tab 'log' })

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

$ui.CheckUpdBtn.Add_Click({ Start-ManualUpdateCheck })

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

$ui.GuideBtn.Add_Click({ Show-GpuGuideDialog (Get-HardwareInfo) })

$ui.DisclaimerBtn.Add_Click({ Show-DisclaimerDialog -ReadOnly | Out-Null })

# 上传诊断报告：先组装（含脱敏）再让用户确认要发什么，确认后才上传。绝不静默发送
$ui.ReportBtn.Add_Click({
  try {
    Write-Log '正在收集诊断信息…'
    $report = New-DiagnosticReport
    $kb = [math]::Round([Text.Encoding]::UTF8.GetByteCount($report) / 1KB, 1)
    $msg = @(
      "将把以下内容上传到作者的服务器（$script:ReportUploadUrl），仅用于排查你反馈的问题："
      ''
      '· 硬件型号与系统版本（CPU / 显卡 / 内存 / Windows 版本）'
      '· 各优化项的当前状态'
      '· 本次运行日志'
      '· 最近一次备份的项目清单（只有项目名，不含注册表原值）'
      '· 本工具的版本号'
      ''
      "路径中的用户名、机器名已替换为 <user> / <pc>。报告大小约 $kb KB。"
      '上传成功后会给你一个取件码，发给开发者即可。'
    ) -join "`n"
    if (-not (Show-ConfirmDialog '上传诊断报告' 'UPLOAD REPORT' $msg '确认上传')) {
      Write-Log '已取消上传诊断报告。'
      return
    }
    Set-BusyState $true
    Write-Log '正在上传诊断报告…'
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $code = Invoke-ReportUpload $report
    if (-not $code) { throw '服务器没有返回取件码' }
    Write-Log "诊断报告上传成功，取件码：$code"
    Show-ConfirmDialog '上传成功' 'UPLOAD OK' "取件码：$code`n`n把这个码发给开发者，他就能取到你这份报告。`n（取件码也已写进上面的运行日志，可用「复制」按钮一并带走）" '知道了' -InfoOnly | Out-Null
  } catch {
    # 失败绝不含糊：说清原因并引导走「复制日志」手工发送
    Write-Log "诊断报告上传失败：$($_.Exception.Message)"
    Show-ConfirmDialog '上传失败' 'UPLOAD FAILED' "上传失败：$($_.Exception.Message)`n`n可能是网络不通、服务暂时不可用，或短时间内上传次数过多。`n`n改用手工方式：点运行日志右侧的「复制」按钮，把日志粘贴发给开发者即可。" '知道了' -InfoOnly | Out-Null
  } finally { Set-BusyState $false }
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
        # 已就绪的项不勾（与全选框同一语义，v0.13）：方案表达的是「要达到的状态」，
        # 已达标的再执行一遍只会撑大备份
        $cb.IsChecked = (($ids -contains $cb.Tag) -and ($row.Tag -ne $true))
      }
    } finally { $script:ApplyingPreset = $false }
    $ui.PresetNote.Text = $p.Note
    Update-Count
    $selN = @((@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children)) |
              Where-Object { $_.Child.Children[0].IsChecked }).Count
    Write-Log "已套用方案「$($p.Name)」（勾选 $selN / $($ids.Count) 项，已就绪的不重复执行）"
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
    # 危险区域的勾选此前被整个忽略（勾了也不执行、不提示）：单独收集，走独立的
    # 高风险二次确认，确认后才带 AllowRisky 交给引擎
    $riskyIds = @($ui.RiskyPanel.Children | Where-Object { $_.Child.Children[0].IsChecked } |
                  ForEach-Object { $_.Child.Children[0].Tag })
    if ($ids.Count -eq 0 -and $riskyIds.Count -eq 0) { Write-Log '未勾选任何优化项。'; return }
    $applyTier = Get-SelectedTelemetryConfigTier ($ids.Count + $riskyIds.Count)
    $optAll = @(Get-OptItems $script:TargetExe $script:SelectedGpuSpoofModel)
    if ($riskyIds.Count -gt 0) {
      $riskySel = @($optAll | Where-Object { $riskyIds -contains $_.Id })
      $rmsg = "将执行以下显卡型号伪装设置：`n`n" +
              (@($riskySel | ForEach-Object { "· $($_.Name)`n  $(if ($_.Warn) { $_.Warn } else { $_.Note })" }) -join "`n`n") +
              "`n`n目标型号：$script:SelectedGpuSpoofModel`n`n确认后将与其余勾选项一起执行（改动前自动备份，可一键还原）。"
      if (Show-ConfirmDialog '显卡型号伪装' 'GPU MODEL SPOOF' $rmsg '确认执行') {
        $ids = @($ids + $riskyIds)
      } else {
        Write-Log "已取消 $($riskyIds.Count) 个高风险项，本次不执行它们。"
        $riskyIds = @()
        if ($ids.Count -eq 0) { Write-Log '取消高风险项后没有剩余可执行项。'; return }
      }
    }
    $names = @($optAll | Where-Object { $ids -contains $_.Id } | ForEach-Object { $_.Name })
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
    # AllowRisky 只在用户刚通过高风险二次确认时才为真，绝不默认放行
    $r = Invoke-Apply $ids $script:TargetExe ($riskyIds.Count -gt 0) ${function:Update-ApplyProgress} $script:SelectedGpuSpoofModel
    $okN = @($r.Results | Where-Object Ok).Count
    $attList = @($r.Results | Where-Object Attention)
    $skipList = @($r.Results | Where-Object { -not $_.Ok -and $_.Skipped })
    $failList = @($r.Results | Where-Object { -not $_.Ok -and -not $_.Skipped -and -not $_.Attention })
    $total = @($r.Results).Count
    if ($okN -gt 0) { Set-TelemetryConfigTier $applyTier }
    Send-AnonymousTelemetry 'apply' $script:HardwareInfo $okN $failList.Count
    # 明确的完成度结论：进度条区和日志各给一份，失败项单独列出让用户一眼看到；
    # 体检发现的问题单列——那是检测项立功了，混进「失败」会让用户误以为工具坏了
    $att = $(if ($attList.Count -gt 0) { " / $($attList.Count) 项体检发现问题" })
    $ui.ProgText.Text = "执行完成：$okN 成功 / $($failList.Count) 失败 / $($skipList.Count) 跳过$att"
    $ui.ProgCount.Text = "共 $total 项"
    if ($r.Backup) { Write-Log "备份已保存：$($r.Backup)" }
    # 备份写盘失败 = 「系统改了、凭据没记全」，比任何一项优化失败都严重：
    # 日志 + 弹窗双通道警告，并把已生效项名和抢救出的部分备份当场给到用户
    if ($r.BackupError) {
      $lost = @($r.UnrecordedNames)
      Write-Log "！！严重：备份文件写入失败（$($r.BackupError)），剩余优化项已中止执行。"
      if ($lost.Count -gt 0) { Write-Log "！！以下已生效的改动可能没有完整的备份记录：$($lost -join '、')" }
      $warn = "备份文件写入失败，本轮执行已中止。`n`n以下改动已经生效、但可能没有完整的备份记录：`n" +
              $(if ($lost.Count -gt 0) { @($lost | ForEach-Object { "· $_" }) -join "`n" } else { '（无）' }) +
              "`n`n失败原因：$($r.BackupError)" +
              $(if ($r.Backup) { "`n`n已抢救出部分备份：$(Split-Path -Leaf $r.Backup)，「还原设置」可还原其中已记录的部分。" }) +
              "`n`n其余项如需回退，请按上面的项名手动处理，或点「上传诊断报告」联系开发者。"
      Show-ConfirmDialog '备份写入失败' 'BACKUP WRITE FAILED' $warn '我已知晓' -InfoOnly | Out-Null
    }
    Write-Log "执行完成：共 $total 项 — $okN 成功、$($failList.Count) 失败、$($skipList.Count) 跳过$(if ($attList.Count -gt 0) { "、$($attList.Count) 项体检发现问题" })。"
    # 日志在另一页了：有失败/体检问题就给标签打角标，提示那边有内容值得看
    Set-LogBadge ($failList.Count + $attList.Count)
    if ($failList.Count -gt 0) {
      # 失败明细也在优化页当场列出，用户不必为了看结果切页
      $ui.ProgText.Text = "执行完成：$okN 成功 / $($failList.Count) 失败 / $($skipList.Count) 跳过$att —— 失败：$(@($failList | ForEach-Object { $_.Name }) -join '、')"
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
    if ($failN -eq 0) { Set-TelemetryConfigTier 'baseline' -Force }
    Send-AnonymousTelemetry 'restore' $script:HardwareInfo $r.RestoredOps $failN
    $bakName = Split-Path -Leaf $r.File
    $ui.ProgText.Text = "还原完成：$($r.RestoredOps) 项已还原 / $failN 项失败$(if ($skipN -gt 0) { " / $skipN 项跳过（无实际影响）" })"
    $ui.ProgCount.Text = "备份：$bakName"
    Write-Log "已还原 $($r.RestoredOps) 项改动（备份：$($r.File)）"
    foreach ($f in $r.Failed) { Write-Log "[还原失败] $f" }
    # 跳过与失败必须分开呈现：跳过是「删不掉但不影响任何生效设置」，混在失败里会吓到用户
    foreach ($s in $r.Skipped) { Write-Log "[还原跳过] $s" }
    foreach ($n in $r.Notes) { Write-Log "[提示] $n" }
    Update-ItemList
    # 成功与否都要有明确收尾：全成给定心丸，有失败的把数量点出来引导看日志。
    # 引擎已合并还原全部未消费备份，「回到优化前」只在零失败时才是事实，失败时必须如实说
    $sum = "已按$(if ($r.MergedCount -gt 1) { "合并的 $($r.MergedCount) 份备份" } else { "备份「$bakName」" })还原 $($r.RestoredOps) 项改动。" +
           $(if ($skipN -gt 0) { "`n`n$skipN 项跳过：工具自建电源方案里的残留设置，该方案已停用，无实际影响。" }) +
           $(if ($failN -gt 0) { "`n`n有 $failN 项还原失败，对应改动仍留在系统中（备份已保留，可排查后重试还原），明细见运行日志。" }
             elseif ($skipN -gt 0) { "`n`n其余全部还原成功，各项已回到优化前的状态。" }
             else { "`n`n全部还原成功，各项已回到优化前的状态。" })
    Show-ConfirmDialog '还原完成' 'RESTORE DONE' $sum '知道了' -InfoOnly | Out-Null
  } catch { Write-Log "还原失败：$($_.Exception.Message)" }
  finally { Set-BusyState $false }
})

# 免责声明门控放在主窗口之前：没同意就不该看到任何可点的优化按钮。
# 读取/写入配置失败一律按「没同意」处理——宁可多问一次，也不能因为磁盘异常就放行
if (-not (Test-DisclaimerAccepted)) {
  if (-not (Show-DisclaimerDialog)) { Invoke-AppExit }
}

$window.ShowDialog() | Out-Null
