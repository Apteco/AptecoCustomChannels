################################################
#
# TODO
#
################################################


# TODO [ ] make the B2B/B2C slider work
# TODO [ ] load configuration file (load objects as tabs, selected fields, soql)
# TODO [ ] resolve picklist values for picklist fields


################################################
#
# LINKS
#
################################################

<#

https://stackoverflow.com/questions/25637033/should-i-be-able-to-use-an-observablecollectionpsobject-as-the-itemssource-of
https://blog.netnerds.net/2016/01/showdialog-sucks-use-applicationcontexts-instead/
https://stackoverflow.com/questions/13951303/whats-the-easiest-way-to-clone-a-tabitem-in-wpf
https://stackoverflow.com/questions/29613572/error-handling-for-invoke-restmethod-powershell

#>




################################################
#
# PREPARATION / ASSEMBLIES
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 | ConvertFrom-Json

# Load more assemblies for WPF
Add-Type -AssemblyName presentationframework, presentationcore, WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms, System.Web
[System.Windows.Forms.Application]::EnableVisualStyles();


########################################################################
#                                                                      #
# SETTINGS                                                             #
#                                                                      #
########################################################################

# access token path
$accesstokenpath = "$( $scriptPath )\access.token"

# Icon for wpf (much more complicated than for winforms, where you only would need the first step)
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($settings.general.iconSource) 
[System.Drawing.Bitmap]$bmp = $icon.ToBitmap()
$stream = New-Object -TypeName System.IO.MemoryStream
$bmp.save($stream, [System.Drawing.Imaging.ImageFormat]::Png.Guid)
[System.Windows.Media.ImageSource]$iconSource = [System.Windows.Media.Imaging.BitmapFrame]::Create($stream)


$xamlFile = $settings.general.xamlConfig

$selectionColumnName = $settings.load.selectionColumnName
$checkboxColumnName = $settings.load.checkboxColumnName


################################################
#
# LOAD WPF XAML
#
################################################


$wpf = @{  }

$inputXml = Get-Content -Path $xamlFile
$inputXMLClean = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace 'x:Class=".*?"','' -replace 'd:DesignHeight="\d*?"','' -replace 'd:DesignWidth="\d*?"',''
[xml]$xaml = $inputXMLClean
$reader = New-Object System.Xml.XmlNodeReader $xaml

$tempform = [System.Windows.Markup.XamlReader]::Load($reader)

$namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")

#add all the named nodes as members to the $wpf variable, this also adds in the correct type for the objects.
$namedNodes | ForEach-Object {
	$wpf.Add($_.Name, $tempform.FindName($_.Name))
}





################################################
#
# SETUP ELEMENTS
#
################################################

# setup window
$window = $wpf.MWind
$window.Icon = $iconSource
$window.Title = $settings.general.windowTitle

# timer for filter inputs
$timer1 = New-Object -TypeName System.Windows.Forms.Timer
$timer1.Interval = $settings.general.filterTickDuration
$timer1.stop()
$countdown = [timespan]::FromSeconds(0)





########################################################################
#                                                                      #
# FUNCTIONS                                                            #
#                                                                      #
########################################################################


function cloneElement($nodeName) {
    
    $s = [System.Windows.Markup.XamlWriter]::Save($tempform.FindName($nodeName))
    $sr = [System.IO.StringReader]::new($s)
    [System.Xml.XmlReader] $xmlReader = [System.Xml.XmlTextReader]::Create($sr,[System.Xml.XmlReaderSettings]::new())
    $new = [System.Windows.Markup.XamlReader]::Load($xmlReader)
        
    return $new

}


function fillDatagrid([System.Windows.Controls.DataGrid]$datagrid, [System.Array]$data, [bool]$preselection=$false, [System.Array]$firstFields, [System.Windows.Controls.Primitives.ButtonBase] $buttonAll, [System.Windows.Controls.Primitives.ButtonBase] $buttonNone, [System.Windows.Controls.TextBox] $soqlPreview, $table) {

    # create new column for selecting them
    $data = $data | Select @{Name=$selectionColumnName ;Expression={$false} }, *    

    # Pre-Selection for IDs etc
    if($preselection -eq $true) {
        $data | where { $_.nameField -eq $true -or $_.idLookup -eq $true } | ForEach {
            $_.$selectionColumnName = $true
            $_.$selectionColumnName = $true
        }
    }

    # settings for datagrid
    $datagrid.AutoGenerateColumns = $true
    $datagrid.CanUserAddRows = $false
    $datagrid.FrozenColumnCount = 4
    
    # bind data to datagrid
    $results2 = New-Object -TypeName System.Collections.ObjectModel.ObservableCollection[Object] -ArgumentList @(,$data)    
    $view = [System.Windows.Data.ListCollectionView]::new($results2)
    #$view.GroupDescriptions.add([System.Windows.Data.PropertyGroupDescription]::new("custom"))
    $datagrid.ItemsSource = $view
    
    # bind some objects to datagrid
    $datagrid.Tag = @{firstFields=$firstFields; data=$data; view=$view;soqlPreview=$soqlPreview}

    # additional column for select fields
    $binding = New-Object -TypeName System.Windows.Data.Binding -Property @{ Path=$selectionColumnName; UpdateSourceTrigger="PropertyChanged"; Mode=[System.Windows.Data.BindingMode]::TwoWay; NotifyOnSourceUpdated = $true } # the propertychanged changes the binded source column directly, the NotifyOnSourceUpdated triggers an Change Event on the datagrid
    $style = [System.Windows.Style]::new([System.Windows.Controls.DataGridCell])
    $style.Setters.add( ( New-Object -TypeName System.Windows.Setter -Property @{ Property=[System.Windows.Controls.DataGridCell]::HorizontalAlignmentProperty; Value=[System.Windows.HorizontalAlignment]::Center }) )
    $style.Setters.add( ( New-Object -TypeName System.Windows.Setter -Property @{ Property=[System.Windows.Controls.DataGridCell]::HorizontalContentAlignmentProperty; Value=[System.Windows.HorizontalAlignment]::Stretch }) )
    $checkbox = [System.Windows.FrameworkElementFactory]::new( ( [System.Windows.Controls.CheckBox] ) )
    $checkbox.SetBinding([System.Windows.Controls.CheckBox]::IsCheckedProperty, $binding )    
    $dataTemplate = New-Object -TypeName System.Windows.DataTemplate -Property @{ VisualTree = $checkbox }
    $col = New-Object -TypeName System.Windows.Controls.DataGridTemplateColumn -Property @{ Header = $checkboxColumnName; CellTemplate = $dataTemplate; CellStyle=$style }    
    $datagrid.columns.Add($col)



    
    # prefill the soql window
    if ($soqlPreview) {
        $soqlPreview.Text = "SELECT * FROM $( $table )"
        fillSOQL -data $data -textbox $soqlPreview
    }


    
    # add events 
    
    $datagrid.add_AutoGeneratedColumns({param([object] $sender, [System.EventArgs] $evtArgs)
        
        $datagrid = $sender

        # Hide the bounded column for the checkbox
        ($datagrid.Columns.Where( { $_.Header -eq $selectionColumnName  } ))[0].Visibility = [System.Windows.Visibility]::Hidden
        
        # Change order of columns to make it more readable
        $i = 1
        $sender.Tag.firstFields | ForEach {
            $header = $_
            #Write-Host $header
            ($datagrid.Columns.Where( { $_.Header -eq $header } ))[0].DisplayIndex = $i++
        }

        # Make columns sortable
        $datagrid.Columns | ForEach {
            $_.CanUserSort = $true
            $_.IsReadOnly = $true
        }

    })

    <#
    $datagrid.add_Loaded({param([object] $sender, [System.EventArgs] $evtArgs)
        # Make columns sortable
        $datagrid.Columns | ForEach {            
            $_.Width = [System.Windows.Controls.DataGridLength]::new($_.ActualWidth, [System.Windows.Controls.DataGridLengthUnitType]::Pixel)
        }
    })
    #>

    if($buttonAll) {

        $buttonAll.Tag = @{ data=$data; view=$view; soqlPreview=$soqlPreview }

        $buttonAll.add_Click({param([object] $sender, [System.EventArgs] $evtArgs)
    
            # Nice, change the original data and it will be appear after refresh the "view"
            $sender.Tag.data | ForEach {
                $_.$selectionColumnName = $true
            }

            $sender.Tag.view.Refresh()
            fillSOQL -data $sender.Tag.data -textbox $sender.Tag.soqlPreview

        })

    }

    if($buttonNone) {

        $buttonNone.Tag = @{ data=$data; view=$view; soqlPreview=$soqlPreview }

        $buttonNone.add_Click({param([object] $sender, [System.EventArgs] $evtArgs)

            # Nice, change the original data and it will be appear after refresh the "view"
            $sender.Tag.data | ForEach {
                $_.$selectionColumnName = $false
            }

            $sender.Tag.view.Refresh()
            fillSOQL -data $sender.Tag.data -textbox $sender.Tag.soqlPreview

        })
    }
    
    if ($soqlPreview) {
        $datagrid.add_SourceUpdated({param([object] $sender, [System.EventArgs] $evtArgs)
        
            $name = $evtArgs.Source.Currentitem.name

            # check the changed value: true -> create new tab, false -> delete tab
            if ( $evtArgs.Source.Currentitem.$selectionColumnName -eq $true ) {                        

                Write-Host "add $($name)"
            
            
            } else {
            
                Write-Host "remove $($name)"

            }

            fillSOQL -data $sender.Tag.data -textbox $sender.Tag.soqlPreview

        })
    }
    

}




function selectObjects([System.Windows.Controls.DataGrid] $datagrid, [System.Array] $list) {
        
        $datagrid.items | ForEach {
            
            #$_.$selectionColumnName = $false
            if ($_.name -in $list) {                
                $_.$selectionColumnName
            }
        }

        <#            
        $datagrid.Tag.data | ForEach {
            
            
            $_.$selectionColumnName = $false
            if ($_.name -in $list) {                
                $_.$selectionColumnName = $true
            }
            

        }
        #>
        

        $datagrid.Tag.view.Refresh()

}


function fillSOQL([System.Array]$data, [System.Windows.Controls.TextBox]$textbox) {
    $cols = ( $data | where { $_.$selectionColumnName -eq $true } ).name -join ", "
    $textbox.Text = $textbox.Text -replace $settings.general.soqlPattern, $cols
}

function ExitWithCode
{
    param
    (
        $exitcode
    )

    $exitcode = 0

    $host.SetShouldExit($exitcode)    

    if ($settings.general.useApplicationContext -eq $true) {    
        #$window.exitCode = $exitcode
        [System.Environment]::ExitCode = 0
        #Return 0
        $Env:Errorlevel = 0
        [System.Windows.Forms.Application]::Exit()#; Stop-Process $pid
       
        #Environment.Exit(0)
    } else {
        exit $exitcode
    }
} 




########################################################################
#                                                                      #
# SETUP SETTINGS                                                       #
#                                                                      #
########################################################################


# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols



########################################################################
#                                                                      #
# FILL GUI                                                             #
#                                                                      #
########################################################################

# For first API call, check if unauthorized. If it is -> refresh the token
$tries = 0
do {    
    try {
        if ($tries -eq 1) { Write-Host "Refreshing token" }
        $accessToken = Get-Content $accesstokenpath
        $bearer = @{ "Authorization" = ("Bearer", $accessToken -join " ") }
        $res = Invoke-RestMethod -Uri "$( $settings.salesforce.uri.endpoint )sobjects/"  -Headers $bearer  -Method Get
    } catch {
        # 401 = unauthorized
        if ($_.Exception.Response.StatusCode.value__ -eq "401") { 
            powershell.exe -File "$( $scriptPath )\salesforce__1b__refresh.ps1"
        } 
    } 
} until ( $tries++ -eq 1 -or $res) # this gives us one retry


# fill the objects into the datagrid
$sobjects = $res.sobjects | select *, @{name="endpoint";expression={ $_.urls.sobject }}
fillDatagrid -datagrid $wpf.datagridSettings -data $sobjects -preselection $false -firstFields $settings.load.sobjectsFirstFields


# remove template tab, it is still ready for cloning from $wpf object
$item = $wpf.tabCollection.items | where { $_.Name -eq $settings.general.templateTabName }
$wpf.tabCollection.items.Remove($item)




################################################
#
# EVENTS
#
################################################

<#
# Initial loading of slider
$wpf.sliderBModel.add_Loaded({param([object] $sender, [System.EventArgs] $evtArgs)

    $wpf.defaultObjects.Text = $settings.salesforce.sobjects.B2B -join ", "
    selectObjects -datagrid $wpf.datagridSettings -list $settings.salesforce.sobjects.B2B

})



# load if slider changes
$wpf.sliderBModel.add_ValueChanged({param([object] $sender, [System.EventArgs] $evtArgs)

    if ($sender.value -eq 1) {

        $wpf.defaultObjects.Text = $settings.salesforce.sobjects.B2B -join ", "
        selectObjects -datagrid $wpf.datagridSettings -list $settings.salesforce.sobjects.B2B

    } else {
        
        $wpf.defaultObjects.Text = $settings.salesforce.sobjects.B2C -join ", "        
        selectObjects -datagrid $wpf.datagridSettings -list $settings.salesforce.sobjects.B2C

    }

})
#>

$wpf.applyConfig.add_Click({param([object] $sender, [System.EventArgs] $evtArgs)
    
            $wpf.MWind.Close()

        })

$wpf.datagridSettings.add_SourceUpdated({param([object] $sender, [System.EventArgs] $evtArgs)
        
        $name = $evtArgs.Source.Currentitem.name

        # check the changed value: true -> create new tab, false -> delete tab
        if ( $evtArgs.Source.Currentitem.$selectionColumnName -eq $true ) {                        

            Write-Host "add $($name)"
            $n1 = cloneElement -nodeName $settings.general.templateTabName
            $n1.Header = $name
            $n1.Name = $name
            $wpf.tabCollection.Items.add($n1)

            $data = Invoke-RestMethod -Uri "$( $settings.salesforce.uri.endpoint )sobjects/$( $name )/describe"  -Headers $bearer  -Method Get
            fillDatagrid -datagrid $n1.FindName("datagrid") -data $data.fields -preselection $true -buttonAll $n1.FindName("buttonAll") -buttonNone $n1.FindName("buttonNone") -firstFields $settings.load.describeFirstFields -soqlPreview $n1.FindName("soqlPreview") -table $name


        } else {
            
            Write-Host "remove $($name)"
            $item = $wpf.tabCollection.items | where { $_.Name -eq $name }
            $wpf.tabCollection.items.Remove($item)

        }

    })


$timer1.add_Tick({

    #Write-Host $script:countdown.TotalMilliseconds

    if ($script:countdown.TotalMilliseconds -eq 0) {
        
        $script:timer1.stop()
        $script:wpf.datagridSettings.ItemsSource.Filter = {param([object] $obj) 
            return $obj.name.ToLower().Contains($script:wpf.filterByName.Text.ToLower())
        }        

    } else {
        $script:countdown -= [timespan]::FromMilliseconds($settings.general.filterTickDuration)        
	}

})

$wpf.filterByName.add_TextChanged({param([object] $sender, [System.EventArgs] $evtArgs)
    
    # with every type fill up the countdown
    $script:countdown = [timespan]::FromMilliseconds($script:settings.general.filterAfterMilliseconds)
    $script:timer1.Start()

    #write-host $evtArgs.Source.Text

    
    # Filter direct
    #$wpf.datagridSettings.ItemsSource.Filter = {param([object] $obj) 
    #    return $obj.name.ToLower().Contains($evtArgs.Source.Text)
    #}


})



# Add Exit
$window.Add_Closing({
    
    # Write configuration as json if windows closes

    $sf = New-Object -TypeName PSCustomObject
    $wpf.tabCollection.Items.where({ $_.Name -ne "SettingsTab" }) | ForEach {
        
        
        $item = [PSCustomObject]@{
            fields=$_.FindName("datagrid").items.name;
            soql=$_.FindName("soqlPreview").Text 
        }
        $sf | Add-Member -MemberType NoteProperty -name $_.Name -Value $item
        
    }
    
    $json = $sf | ConvertTo-Json -Depth 8 # -compress

    Write-Host $json

    cd "$( $scriptPath )"
    $confirmReplace = .\New-MessageBox.ps1 -Message "Do you want to replace the existing configuration file?" -Title "Replace file" -Button YesNo -Icon Warning
    if ($confirmReplace -eq "Yes") {
        $json | Set-Content -path "$( $scriptPath )\configuration.json" -Encoding UTF8
    }

    # exit the window and the corresponding processes
   ExitWithCode -exitcode 0

})



################################################
#
# PROCESS
#
################################################


# Make PowerShell disappear 
if ($settings.general.hidePowerShell -eq $true) {
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' 
    $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru 
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0) 
}

# Show window
if ($settings.general.useApplicationContext -eq $true) {

    # Running this without $appContext and ::Run would actually cause a really poor response.
    $window.Show()
 
    # This makes it pop up
    $window.Activate()
 
    # Create an application context for it to all run within. 
    # This helps with responsiveness and threading.

    # Allow input to window for TextBoxes, etc
    [System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($window)
    
    $appContext = New-Object System.Windows.Forms.ApplicationContext 
    [void][System.Windows.Forms.Application]::Run($appContext)

} else {

    $window.ShowDialog() | Out-Null

}




#$wpf.datagrid.Items | where { $_.$selectionColumnName -eq $true } | Out-GridView









################################################
#
# ARCHIVE
#
################################################




# This method is not really useful as you have to mark the row first and then tick the checkbox
<#
# column for select fields
$col = [System.Windows.Controls.DataGridCheckBoxColumn]::new()
$col.Header = "Auswahl"
$col.ElementStyle = ""
$wpf.datagrid.columns.Add($col)
#>