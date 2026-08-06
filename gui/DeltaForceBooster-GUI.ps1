<#
  DeltaForceBooster 图形界面 — v0.6
  视觉基准：三角洲行动国服官网 df.qq.com 实测提炼（用户提供截图）：
    近黑微青顶栏 #0D1417 + 页面青绿细渐变 #0A1512→#10201C + 正绿 CTA #00E884（斜切角 +
    等高线纹理）+ 金色分类标签 #E5C46A + 中英上下叠排分区标题（选中态绿色下划线）
    + 侧边刻度尺装饰 + 等宽技术标注 + 「— — 中 文 拉 字 距 — —」式装饰分隔线。
  双击根目录「启动优化工具.bat」运行；本文件点源加载 scripts\delta-booster.ps1 作为引擎，
  scripts\updater.ps1 作为更新检查模块（异步、静默失败、绝不自动下载）。
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
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\delta-booster.ps1')

# 界面版本号：标题栏徽标 / 页脚 / 更新检查共用同一处定义，避免三处漂移
$script:GuiVersion = '0.6'
$script:UpdaterPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\updater.ps1'
# 更新模块独立可缺失：老用户手动拷贝升级时可能没有该文件，缺了也不能影响主功能
if (Test-Path -LiteralPath $script:UpdaterPath) { try { . $script:UpdaterPath } catch {} }

Add-Type -AssemblyName PresentationFramework

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="三角洲行动 · 画面优化助手" Width="780" Height="830"
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
                  <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="#FF04241B"
                        StrokeThickness="2" Visibility="Collapsed"/>
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
          <TextBlock Text="[ v0.6 ]" Style="{StaticResource Mono}" Foreground="{StaticResource Green}" Margin="9,0,0,0"/>
        </StackPanel>
        <!-- 等宽技术标注块：官网左上角 DELTA FORCE / S.T.I SQUAD 手法 -->
        <TextBlock Text="S.T.I // SYS-BOOST" Style="{StaticResource Mono}" FontSize="9"
                   HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,84,0"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="MinBtn" Content="—" Style="{StaticResource WinBtn}"/>
          <Button x:Name="CloseBtn" Content="✕" Style="{StaticResource WinBtn}"/>
        </StackPanel>
      </Grid>
    </Border>

    <Grid Grid.Row="1">
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
              <TextBlock Text="作战单元" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="SYSTEM LOADOUT" Style="{StaticResource HeadEn}"/>
              <Border Style="{StaticResource HeadBar}"/>
            </StackPanel>
            <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                    VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <TextBlock Grid.Column="2" x:Name="ScanState" Text="侦察中…" Style="{StaticResource Mono}"
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
              <TextBlock Text="作战指令" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="OPTIMIZE ORDERS" Style="{StaticResource HeadEn}"/>
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
            <StackPanel x:Name="ItemPanel"/>
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
            <TextBlock Text="战 术 优 化 · 改 前 备 份 · 一 键 还 原" Foreground="{StaticResource TextMut}"
                       FontSize="10" Margin="10,0" VerticalAlignment="Center"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
          </StackPanel>

        </StackPanel>
      </ScrollViewer>
    </Grid>

    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="29,6,29,8">
      <!-- 主 CTA：绿色实底 + 深色字 + 左侧图标（官网下载按钮三要素） -->
      <Button x:Name="ApplyBtn" Style="{StaticResource Primary}" Width="230">
        <StackPanel Orientation="Horizontal">
          <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF04241B"
                Width="18" Height="15" Stretch="Uniform" VerticalAlignment="Center" Margin="0,0,9,0"/>
          <TextBlock Text="执行优化" VerticalAlignment="Center"/>
        </StackPanel>
      </Button>
      <Button x:Name="RestoreBtn" Content="撤离还原" Style="{StaticResource Ghost}" Width="130" Margin="9,0,0,0"/>
      <Button x:Name="RefreshBtn" Content="重新侦察" Style="{StaticResource Ghost}" Width="115" Margin="9,0,0,0"/>
      <Button x:Name="GuideBtn" Content="显卡指引" Style="{StaticResource Ghost}" Width="115" Margin="9,0,0,0"/>
    </StackPanel>

    <StackPanel Grid.Row="3" Margin="29,0,29,6">
      <Grid Margin="0,0,0,5">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal">
          <TextBlock Text="作战日志" Foreground="{StaticResource TextPri}" FontSize="12"
                     FontWeight="Bold" VerticalAlignment="Center"/>
          <TextBlock Text="COMBAT LOG" Style="{StaticResource Mono}" FontSize="8" Margin="8,2,0,0"/>
        </StackPanel>
        <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                VerticalAlignment="Center" Margin="12,0,0,0"/>
      </Grid>
      <Border Background="{StaticResource LogBg}" BorderBrush="{StaticResource Line}" BorderThickness="1">
        <TextBox x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap" Height="58"
                 VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="Transparent"
                 Foreground="#FF9AA5A0" FontFamily="Consolas" FontSize="11" Padding="9,6"/>
      </Border>
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
      <TextBlock Grid.Column="0" Text="DELTA FORCE · BOOSTER" Style="{StaticResource Mono}" FontSize="9"/>
      <Border Grid.Column="1" Width="26" Height="2" Background="{StaticResource Gold}" VerticalAlignment="Center" Margin="9,0,0,0"/>
      <Border Grid.Column="2" Height="1" Background="{StaticResource LineSoft}" VerticalAlignment="Center" Margin="9,0"/>
      <Border Grid.Column="3" Width="5" Height="5" BorderBrush="{StaticResource Green}" BorderThickness="1" VerticalAlignment="Center" Margin="0,0,9,0"/>
      <TextBlock Grid.Column="4" Text="[ V0.6 ] 改动前自动备份 · 可一键撤离还原" Style="{StaticResource Mono}" FontSize="9"/>
    </Grid>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
$ui = @{}
foreach ($n in 'TitleBar','MinBtn','CloseBtn','ScanState','HwGrid','GameText','BrowseBtn','CountText',
               'ItemPanel','RiskyGroup','RiskyPanel','ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','LogBox',
               'PresetBox','SavePresetBtn','DelPresetBtn','PresetNote') {
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
  $sel = @($ui.ItemPanel.Children | Where-Object { $_.Child.Children[0].IsChecked }).Count
  $ui.CountText.Text = "已选 $sel / $($ui.ItemPanel.Children.Count)"
}

function New-ItemRow($Item, $State, [bool]$Last) {
  $row = New-Object Windows.Controls.Border
  if (-not $Last) {
    $row.BorderBrush = New-Brush $script:C.LineSoft
    $row.BorderThickness = New-Object Windows.Thickness 0, 0, 0, 1
  }
  $row.Padding = New-Object Windows.Thickness 10, 0, 10, 0

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

  # 状态徽标（官网金色分类标签改造）：就绪=绿实底，待优化=金实底，待定=灰描边
  $pill = if ($State.Optimized -eq $true) { New-Pill '已就绪' $script:C.GreenDark $script:C.Green $script:C.Green }
          elseif ($State.Optimized -eq $false) { New-Pill '待优化' $script:C.GoldDark $script:C.Gold $script:C.Gold }
          else { New-Pill '待定' $script:C.Gray '#00000000' $script:C.Line }
  [Windows.Controls.Grid]::SetColumn($pill, 2)
  $g.Children.Add($pill) | Out-Null

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
    <TextBlock Text="把当前勾选的指令保存为方案，输入方案名：" Foreground="#FF9AA5A0" Margin="14,12,14,8"/>
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

# 更新提醒对话框：只展示信息 + 用浏览器打开下载页，绝不下载/执行任何文件（供应链红线）
function Show-UpdateDialog($UpdInfo) {
  $uxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="430" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
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
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,6,14,10">
      <ScrollViewer MaxHeight="140" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="NotesText" Text="" Foreground="#FF9AA5A0" FontSize="11"
                   TextWrapping="Wrap" Padding="10,8"/>
      </ScrollViewer>
    </Border>
    <Grid Margin="14,0,14,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
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
      <Button x:Name="GoBtn" Grid.Column="1" Width="110" Height="30" Foreground="#FF04241B" FontWeight="Bold">
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
        <TextBlock Text="前往下载"/>
      </Button>
      <Button x:Name="LaterBtn" Grid.Column="2" Width="86" Height="30" IsCancel="True"
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
  # 事件处理器在模态期间回调，跟 Show-NameDialog 一样把要用的对象放 script 作用域最稳
  $script:UpdDlg = [Windows.Markup.XamlReader]::Parse($uxaml)
  $script:UpdDlgInfo = $UpdInfo
  $script:UpdDlg.Owner = $window
  $script:UpdDlg.FindName('VerText').Text = "新版本 v$($UpdInfo.Version)"
  $script:UpdDlg.FindName('CurText').Text = "当前 v$($UpdInfo.Current)"
  $notes = "$($UpdInfo.Notes)".Trim()
  $script:UpdDlg.FindName('NotesText').Text = $(if ($notes) { $notes } else { '（本次更新没有附带说明）' })
  $skipChk = $script:UpdDlg.FindName('SkipChk')
  $script:UpdDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:UpdDlg.DragMove() })
  $script:UpdDlg.FindName('GoBtn').Add_Click({
    # 只允许 http/https：清单被篡改成本地路径/其他协议时拒绝打开，防止借更新入口执行文件
    $u = "$($script:UpdDlgInfo.Url)"
    if ($u -match '^https?://') { Start-Process $u } else { Write-Log '更新清单里的下载地址不是网页链接，已拦截。' }
    $script:UpdDlg.DialogResult = $true
  })
  $script:UpdDlg.FindName('LaterBtn').Add_Click({ $script:UpdDlg.DialogResult = $false })
  $script:UpdDlg.ShowDialog() | Out-Null
  if ($skipChk.IsChecked -and (Get-Command Set-BoosterSkipVersion -ErrorAction SilentlyContinue)) {
    Set-BoosterSkipVersion $UpdInfo.Version
    Write-Log "已设置不再提醒 v$($UpdInfo.Version)。"
  }
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

# 启动后异步检查更新：网络请求放后台运行空间，界面渲染不等它；任何失败静默吞掉
function Start-UpdateCheck {
  if (-not (Get-Command Test-BoosterUpdate -ErrorAction SilentlyContinue)) { return }
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
          Write-Log "检测到新版本 v$($found.Version)（当前 v$($found.Current)）。"
          Show-UpdateDialog $found
        }
      } catch {} finally { $script:UpdateJob.Dispose() }
    })
    $script:UpdateTimer.Start()
  } catch {}
}

$script:TargetExe = $null
$script:PresetList = @()
$script:ApplyingPreset = $false

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

    Write-Log '开始侦察硬件与系统状态…'
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
    $ui.ScanState.Text = '侦察完成'
    Write-Log '侦察完成。选预设方案或手动勾选后点「执行优化」，带 * 的项需要管理员权限。'
    Start-UpdateCheck
  } catch {
    $ui.ScanState.Text = '侦察失败'
    Write-Log "初始化失败：$($_.Exception.Message)"
  }
})

$ui.TitleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$ui.MinBtn.Add_Click({ $window.WindowState = 'Minimized' })
$ui.CloseBtn.Add_Click({ $window.Close() })

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

$ui.GuideBtn.Add_Click({
  $hw = Get-HardwareInfo
  [Windows.MessageBox]::Show((Get-GpuGuideText $hw.MainGpuVendor), '显卡驱动设置指引（需手动）', 'OK', 'Information') | Out-Null
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
    if ($ids.Count -eq 0) { Write-Log '未勾选任何指令，无法存为方案。'; return }
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
    if ([Windows.MessageBox]::Show("删除自存方案「$($p.Name)」？", '确认删除', 'OKCancel', 'Warning') -ne 'OK') { return }
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
    if ($ids.Count -eq 0) { Write-Log '未勾选任何指令。'; return }
    $names = @(Get-OptItems $script:TargetExe | Where-Object { $ids -contains $_.Id } | ForEach-Object { $_.Name })
    $msg = "将执行以下 $($ids.Count) 项优化（改动前自动备份，可一键撤离还原）：`n`n" + ($names -join "`n")
    if ([Windows.MessageBox]::Show($msg, '确认执行', 'OKCancel', 'Question') -ne 'OK') { return }
    $r = Invoke-Apply $ids $script:TargetExe $false
    foreach ($x in $r.Results) { Write-Log "$(if ($x.Ok) { '[完成]' } else { '[跳过]' }) $($x.Name) — $($x.Msg)" }
    if ($r.Backup) { Write-Log "备份已保存：$($r.Backup)" }
    Write-Log '执行结束。电源计划、HAGS 等项重启电脑后完全生效。'
    Update-ItemList
  } catch { Write-Log "执行失败：$($_.Exception.Message)" }
})

$ui.RestoreBtn.Add_Click({
  try {
    if ([Windows.MessageBox]::Show('按最近一次备份撤离还原全部改动？', '确认还原', 'OKCancel', 'Question') -ne 'OK') { return }
    $r = Invoke-Restore $null
    Write-Log "已还原 $($r.RestoredOps) 项改动（备份：$($r.File)）"
    foreach ($f in $r.Failed) { Write-Log "[还原失败] $f" }
    Update-ItemList
  } catch { Write-Log "还原失败：$($_.Exception.Message)" }
})

$window.ShowDialog() | Out-Null
