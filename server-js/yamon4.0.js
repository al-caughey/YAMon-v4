"use strict"
/*
##########################################################################
#																		 #
# Yet Another Monitor (YAMon)											 #
# Copyright (c) 2013-present Al Caughey									 #
# All rights reserved.													 #
#																		 #
##########################################################################
HISTORY
4.0.7 (2020-03-20) - finally got the gauges working on the summary page
4.0.4 (2019-12-28) - lots of bug fixes
4.0.0 (2015-11-16) - first iteration with the new features
*/
var nDevicesReadFailures=0,nMonthlyReadFailures=0,nHourlyReadFailures=0,nLiveReadFailures=0
var _dec,_settings_pswd
var _rs_Date,_re_Date,_cr_Date
var refreshTimer,liveUpdatesTimer,old_last_update
var g_toKB,g_toMB,g_toGB
var monthlyDataCap=null,g_nobwCap
var g_Settings={}, g_IPii={}, g_Restrictions={}, g_SortedCIDR=[]
var bDevicesChanged=true
var devices=[],names=[],monthly=[],hourly=[],hourly_totals={},corrections=[],interfaces={},p_pnd_d=0,p_pnd_u=0,p_dropped=0,p_local=0,o_sut,hourlyloads=[],live=[]
var monthly_totals
var pnd_data={'start':{'down':0,'up':0},'total':{'down':0,'up':0,'dropped':0,'local':0,'lost':0},'usage':[]}
var months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
var _unlimited_usage,_doLiveUpdates=1,_liveFileName='./js/live_data4.js',_doCurrConnections=1,_updatefreq=60,_organizeData=2
var dispUnits=['b','Kb','MB','GB','TB','PB']
var livekbs_do,livekbs_up,s_usage,numLU=1
var gauges,livekbs_do_chart,livekbs_up_chart,sl_chart;
var g_base, darkmodeBG='#888'
var maxGrWidth
var ip2device={}
var _slider_left=0,_slider_right=5
var inDarkMode=false
var colours_list=['DarkOliveGreen','Indigo','MediumPurple','Purple','MidnightBlue','DarkOrange','MediumSeaGreen','Red','Aqua','DarkOrchid','MediumSlateBlue','RosyBrown','AquaMarine','DarkRed','MediumSpringGreen','RoyalBlue','DarkSalmon','MediumTurquoise','SaddleBrown','DarkSeaGreen','LawnGreen','MediumVioletRed','Salmon','DarkSlateBlue','SandyBrown','DarkSlateGray','LightBlue','SeaGreen','DarkTurquoise','Blue','DarkViolet','Sienna','BlueViolet','DeepPink','Silver','Brown','DeepSkyBlue','Navy','SkyBlue','BurlyWood','DimGray','LightGreen','SlateBlue','CadetBlue','DodgerBlue','LightPink','Olive','SlateGray','Chartreuse','FireBrick','LightSalmon','OliveDrab','Chocolate','LightSeaGreen','Orange','SpringGreen','Coral','ForestGreen','LightSkyBlue','OrangeRed','SteelBlue','CornFlowerBlue','Fuchsia','LightSlateGray','Orchid','Tan','LightSteelBlue','PaleGoldenRod','Teal','Crimson','PaleGreen','Thistle','Cyan','Gold','Lime','PaleTurquoise','Tomato','DarkBlue','GoldenRod','LimeGreen','PaleVioletRed','Turquoise','DarkCyan','Gray','Violet','DarkGoldenRod','Green','Magenta','PeachPuff','Wheat','DarkGray','GreenYellow','Maroon','Peru','DarkGreen','MediumAquaMarine','Pink','DarkKhaki','HotPink','MediumBlue','Plum','Yellow','DarkMagenta','IndianRed','MediumOrchid','PowderBlue','YellowGreen','Ivory','Beige','WhiteSmoke','Bisque','Linen','OldLace','LightCoral','Lavender','Azure','Black','PapayaWhip','LightYellow','FloralWhite','LemonChiffon','AntiqueWhite','MintCream','SeaShell','LavenderBlush','LightCyan','LightGoldenrodYellow','BlanchedAlmond','MistyRose','NavajoWhite','Khaki','Moccasin','LightGray','Cornsilk','Gainsboro','HoneyDew','GhostWhite','White','AliceBlue','Snow'],n_colours=colours_list.length
var br0=0 //ugly hack to overcome bad data in hourly usage file for pnd data... ick!
$(document).ready(function (){
	$('.loading-wrapper')
	.click(function(){
		$(this).fadeOut('slow')
	})
	$('.verno').text('v'+_file_version)

	$('.html_version').text(_html_version)
	if(typeof(_version)=='undefined'){
		var _version=4.0 //should never get this because _version should be defined in config4.js?!?
		//To-do - add a getmessage alert that config4.js is not properly configured?!?
	}
	$('.scriptVersion').text(_version)
	_organizeData=2 //To-Do - eliminate references to _organizeData
	
	$( ".report-date" ).slider({
		slide: function( event,ui ) {
			var sv=ui['value'],sv_milli=sv*1000*24*60*60,cr_milli=_rs_Date.valueOf()
			_cr_Date=new Date(cr_milli+sv_milli)
			$('.current-date').text(formattedDate(_cr_Date))
			var cw=$('.sp-current-date').textWidth()*1,mw=$('.sp-current-date').width()*1-_slider_right,nd=$('.report-date').slider('option','max')-1,os=(mw-cw)/nd+_slider_left
			$('.sp-current-date').css('text-indent',os*sv)
		},
		stop: function( event,ui ) {
			var today=new Date();
			if(_cr_Date>today) _cr_Date=today
			$('#daily-tab').removeClass('loaded')
			var hourlyLoaded = loadHourly()
			hourlyLoaded.done(function(){
			});
	   }
	});
	$('#sp_curSL').attr('id','sp_1minSL')
	$('#sp_minSL').attr('id','sp_5minSL')
	$('#sp_minSL').attr('id','sp_15minSL')
	addISPList()
	maxGrWidth=Math.min(1000, $('.tab-div').css('width').replace('px','')-44)

	resetdates()
	//setReportDates()
	var SettingsLoaded =  loadSettings();
	SettingsLoaded.done(function () {
		if (g_Settings['router']==null){
			getMessage('v4 beta');
			uploadRouterJS('save router')
		}
		else if(g_Settings['router']['share']=='1' && _updated!=g_Settings['router']['updated']){
			uploadRouterJS('updated router')
		}
		else if(g_Settings['router']['share']==0){
			$('.shareRouter').parents('p').show()
		}

		checkConfig()
		setSettingsDefaults()
		setGlobals()
		setButtonsActions()
		setViews()
		if(!g_Settings['complete']==1){
			$('#error-notification').fadeOut('slow')
			return false
		}
		if(_doLiveUpdates==1){
			setUpLiveCharts()
		}
		$('.selected').removeClass('selected')
		var wt=$('#defvu').val()||'summary-tab'
		$('#'+wt).addClass('selected')
		//console.log('calling loadDevices')
		var devicesLoaded = loadDevices();
		devicesLoaded.done(function () {
			//console.log('calling loadMonthly')
			var monthlyLoaded = loadMonthly();
			monthlyLoaded.done(function(){
				//console.log('calling loadHourly')
				var hourlyLoaded = loadHourly()
				hourlyLoaded.done(function(){
					$('#error-notification').fadeOut('slow')
				});
			});
		});
	});
	$('#dbkey').attr('title','This is your database key... the value is set in `config'+_file_version+'.js`')
	$("[link*='config3.js'], .l2c").data('link','js/config'+_file_version+'.js').attr('title','View the contents of your `config'+_file_version+'.js` data file')
	if (_doLiveUpdates==1) $('#last_update').attr('href', _liveFileName)
	/*$.getScript( "js/alerts.js")
	.done(function(data){
	})
	.fail(function(data){
		console.log(data)
	})*/
	
	var d = new Date();
	var hr=d.getHours()
	$('#hourly-table').attr('data-showing',hr>=12?'PM':'AM') 
	$('#curr-users').append("<tr><td colspan='100%' class='not-ready-yet no-current-users'>Sorry for the inconvenience but this table is currently not being populated... .  In v4, I changed the way that the live data is collected and I haven't gotten around to fixing the JS code to display it properly. <br/> This will be fixed in v4.0.6 which should be available shortly</td></tr>")
})

$(document).on('pagebeforecreate', function( e ) {
	$( "input, textarea, select", e.target ).data( "role", "none" );
});
$(window).on('beforeunload',function(){
	if(!$('#sv-btn').is(':visible')) return
	return 'You have unsaved changes on the Settings tab.  Leaving now will result in the loss of those changes!'
});
function setViews(){
	
	if(!g_Settings['complete']==1){
		$('#pop-up, .loading-wrapper').hide()
		getIntro()
		return false
	}
	if(_unlimited_usage=='1'){
		$('.th-tot').addClass('click-td btn')
		$('#mb-router-th').attr('colspan',7)
		$('.ul-int').html('Bonus Data Interval<br/>('+ _unlimited_start +' - '+ _unlimited_end +')')
		$('.th-tot').click(function(){
			$('#ul-redtot').click()
		})
	}
}
function loadDevices(){
	//console.log('loadloadDevices - start')
	var deferred = $.Deferred()
	if (_wwwData=='') _wwwData='data4/'
	_wwwData += _wwwData.endsWith("/") ? "" : "/"
	$('.loaded').removeClass('loaded')
	var device_file=_wwwData+'users.js'
	showLoading("Devices from "+device_file)
	$("#devicesData .achanged").removeClass('achanged')
	$.getScript(device_file)
	.done(function(list,textStatus){
		$('#devicesHeader .icon').attr('title', 'View the contents of your `users.js` data file').data('link', device_file)
		if (typeof(users_created)=='undefined'){
			//alert('users_created is not defined... there is likely an error in your users.js')
			getMessage('users_created',device_file);
		}
		else{
			$('#sp_users_created').text(lastmod(users_created,'')).attr('title',users_created)
		}
		nDevicesReadFailures=0
		//console.log('loadloadDevices - ', textStatus)
		deferred.resolve()
	})
	.fail(function(jqxhr,settings,exception){
		//console.log('loadloadDevices - ', exception)

		nDevicesReadFailures++
		var msg='<p>Error #'+nDevicesReadFailures+' reading the devices data file: `<a href="'+device_file+'" target="_blank">'+device_file+'</a>`\n'+exception+'</p>'
		if(nDevicesReadFailures>3){
			ShowAlert(msg,'devices-error')
			showLoading("Could not open the devices file?!? " + exception,'failed' )
			nDevicesReadFailures=0
			deferred.fail()
		}
		else{
			setTimeout(function(){loadDevices()},1500)
		}
	})
	//console.log('loadloadDevices - done')
	return deferred.promise()
}
function loadMonthly(){
	var failcount=0
	function getMonthlyData(myr, mn, da){
		var _usageFileName='mac_usage.js'
		var _hourlyFileName='hourly_data.js'
		var dp=_wwwData+(_organizeData==0?'':(_organizeData==1?myr+'/':myr+'/'+mn+'/'))
		var mdatafile=dp+myr+'-'+mn+'-'+(!da?'':(da+'-'))+_usageFileName
		var md = $.Deferred()
		monthlyDataCap=null
		$.getScript(mdatafile)
		
		.done(function(dlist,textStatus){
			if(dlist==''){
				failcount++
				if (failcount>2){
					showLoading("Could not open the monthly data file?!?  ")
					md.fail()
				}
				else{
					var gmd2 = getMonthlyData(myr, mn, twod(_ispBillingDay))
					gmd2.done(function(){
						md.resolve()
					}).fail(function(){
						md.fail()
					});
				}
				return false
			}
			if (!monthlyDataCap || monthlyDataCap==0){
				$('.spUsageCap').text('Unlimited').removeClass('GBytes')
			}
			else{
				$('.spUsageCap').text(monthlyDataCap).addClass('GBytes')
			}
			flushChanges()
			$('#MonthlyHeader .icon').attr('title', 'View the contents of the monthly usage data file').data('link', mdatafile)
			var cdown=0,cup=0
			for(var d in corrections){
				if(corrections[d]){
					cdown=corrections[d].down*g_toMB
					cup=corrections[d].up*g_toMB
					monthly_totals.down+=cdown
					monthly_totals.up+=cup
					monthly_totals.usage[d].down+=cdown
					monthly_totals.usage[d].up+=cup
			   }
			}
			var today=new Date(), dn=_cr_Date.getDate(), td=formattedDate(today), rd=formattedDate(_cr_Date), dl='', sa=false, dg=false
			var ryr=_rs_Date.getFullYear(), rm=twod(_rs_Date.getMonth()-(-1))
			var dp=_wwwData+(_organizeData==0?'':(_organizeData==1?ryr+'/':ryr+'/'+rm+'/'))
			while (td!=rd && !monthly_totals.usage[dn].down && !monthly_totals.usage[dn].up){
				dn++
				var da=twod(_cr_Date.getDate()), mo=twod(_cr_Date.getMonth()-(-1)), yr=_cr_Date.getFullYear()
				var datafile=dp+'hourly_'+yr+'-'+mo+'-'+da+'.js'
				dl+='<br/> * <a href="'+datafile+'" target="_blank">'+formattedDate(_cr_Date)+'</a>'
				if (dn>31) dn=1
				_cr_Date=newdate(_cr_Date,1)
				sa=true
				if (_cr_Date>=_re_Date) break
			}
			if(sa){
				ShowAlert("<p>Your <a href='"+mdatafile+"' target='_blank'>monthly data</a> file is missing traffic at the start of the interval the following dates:"+dl+"</p><p>Click the links to see if the files and data do exist.  If they do, see `<a href='http://usage-monitoring.com/help/?t=missing-data' target='_blank'>I have gaps in my monthly reports?!?</a>`</p>",'missing-monthly')
				showLoading("The monthly data file has gaps?!?",'warning')
			} 
			var nn=_rs_Date, cd, gl=''
			while (nn<today && nn<=_re_Date){
				cd=formattedDate(nn)
				if(cd==td) break
				var da=twod(nn.getDate()), dn=da*1, mo=twod(nn.getMonth()-(-1)), yr=nn.getFullYear()
				var datafile=dp+'hourly_'+yr+'-'+mo+'-'+da+'.js'
				if(!monthly_totals.usage[dn] || (monthly_totals.usage[dn].down==0 && monthly_totals.usage[dn].up==0)){
					gl+='<br/> * <a href="'+datafile+'" target="_blank">'+cd+'</a>'
					dg=true
					//console.log(nn, today,nn<today)
				}
				nn=newdate(nn,1)
			}
			if((dg) && (dl!=gl)){
				ShowAlert("<p>Your <a href='"+mdatafile+"' target='_blank'>monthly data</a> file is missing traffic on the following dates:"+gl+"</p><p>Click the links to see if the files and data do exist.  If they do, see `<a href='http://usage-monitoring.com/help/?t=missing-data' target='_blank'>I have gaps in my monthly reports?!?</a>`</p>",'monthly-gaps')
				showLoading("The monthly data file has gaps?!?",'warning')
			} 
			md.resolve()
		})
		.fail(function(jqxhr,settings,exception){
			failcount++
			if (failcount>2){
				showLoading("Could not open the monthly data file?!? "+exception,'failed')
				var clf=clearLoading(4000)
				clf.done(function(){
					getMessage('monthly not found', datafile)
				})
				md.fail()
			}
			else{
				var gmd2 = getMonthlyData(myr, mn, twod(_ispBillingDay))
				gmd2.done(function(){
					md.resolve()
				}).fail(function(){
					md.fail()
				});
			}
		})
		return md.promise()
	}
	
	var deferred = $.Deferred()
	var cm=$('#SystemTotalsTable .currentSummary').attr('id'),cleardata=true
	$('#myAlert,.alert-icon').fadeOut('slow')
	setReportDates(cm)
	$('.loaded').removeClass('loaded')
	var yr=_rs_Date.getFullYear(), cmo=_rs_Date.getMonth()*1
	if(_rs_Date.getDate()!=_ispBillingDay)cmo--
	var rm=twod(cmo+1)
	if(!g_Settings['corrections']||!g_Settings['corrections'][rm+'-'+yr]||!g_Settings['corrections'][rm+'-'+yr].length){
		corrections={}
	}
	else{
		corrections=JSON.parse(g_Settings['corrections'][rm+'-'+yr])
	}
	monthly=[]
	zeroDevicesTotal()
	zeroMonthlyTotals()
	if(cleardata)$('#MonthlyBreakdown,#breakdownFooter').html('')
		
	showLoading('Monthly data for ' + yr+'-'+rm)
	var gmd = getMonthlyData(yr, rm)
	gmd.done(function(){
		deferred.resolve()
	}).fail(function(){
		deferred.fail()
	});
	return deferred.promise()

}
function loadHourly(cleardata){
	var deferred = $.Deferred()
	deferred.resolve()
	hourly_totals.usage=[]
	hourly_totals.memory=[]
	hourly_totals.usage={}
	interfaces=[]
	
	if ($('.not-viewed').length==0) $('#myAlert,.alert-icon').fadeOut('slow').removeClass('viewed')
	pnd_data={'start':{'down':0,'up':0},'total':{'down':0,'up':0,'dropped':0,'local':0,'lost':0},'usage':[]}
	hourlyloads=[]
	o_sut=null
	$('.current-date').text(formattedDate(_cr_Date))
	$('.loaded').removeClass('loaded')

	Object.keys(hourly).forEach(function(k){
		chu(k)
	})
	//$('#DailyData').html('')
	$('#DailyData .is_d').addClass('clear')
	
	var dn=_cr_Date.getDate()*1, da=twod(dn)
	var mo=twod(_cr_Date.getMonth()-(-1))
	var yr=_cr_Date.getFullYear()
	$('#monthly-tab-date').text(months[_cr_Date.getMonth()])

	var cmo=_rs_Date.getMonth()*1
	if(_rs_Date.getDate()!=_ispBillingDay)cmo--
	var rm=twod(cmo+1)
	$('#daily-tab-date').text(da)
	var ryr=_rs_Date.getFullYear()
	var dp=_wwwData+(_organizeData==0?'':(_organizeData==1?ryr+'/':ryr+'/'+rm+'/'))
	var datafile=dp+'hourly_'+yr+'-'+mo+'-'+da+'.js'

	var today=new Date()
	var isToday=_cr_Date.toDateString()==today.toDateString()
	if(isToday){
		if(_unlimited_usage=='0'){
			Object.keys(monthly).forEach(function(k){
				monthly[k].usage[dn]={down:0,up:0}
			})
			Object.keys(names).forEach(function(k){
				names[k].usage[dn]={down:0,up:0}
			})
		}
		else{
			Object.keys(monthly).forEach(function(k){
				monthly[k].usage[dn]={down:0,up:0,ul_down:0,ul_up:0}
			})
			Object.keys(names).forEach(function(k){
				names[k].usage[dn]={down:0,up:0,ul_down:0,ul_up:0}
			})
		}
	}
	hourly_totals.down=0
	hourly_totals.up=0
	showLoading('Hourly data for ' + yr+'-'+mo+'-'+da)
	
	if(!monthly_totals.usage[dn]) monthly_totals.usage[dn]={down:0,up:0,ul_down:0,ul_up:0}

	$.getScript(datafile)
	.done(function(dlist,textStatus){
		$('#DailyUsageHeader .icon').attr('title', 'View the contents of the hourly usage data file').data('link', datafile)
		//To-do... get uptime from old v3 data files
		
		if(typeof(users_updated)==='undefined') var users_updated=''
		$('#sp_users_updated').text(lastmod(users_updated,'')).attr('title',users_updated)
		$('#sp_hourly_updated').text(lastmod(hourly_updated,'')).attr('title',hourly_updated)
		$('.hwncd').hide()
		if(isToday){
			monthly_totals.down-=monthly_totals.usage[dn].down
			monthly_totals.up-=monthly_totals.usage[dn].up
			monthly_totals.usage[dn]={down:0,up:0}
			if(_unlimited_usage=='1'){
				monthly_totals.ul_down-=monthly_totals.usage[dn].ul_down
				monthly_totals.ul_up-=monthly_totals.usage[dn].ul_up
				monthly_totals.usage[dn].ul_down=0
				monthly_totals.usage[dn].ul_up=0
			}
			if(corrections[dn]){
				var cdown=corrections[dn].down*g_toMB,cup=corrections[dn].up*g_toMB
				monthly_totals.down+=cdown
				monthly_totals.up+=cup
				monthly_totals.usage[dn].down+=cdown
				monthly_totals.usage[dn].up+=cup
			}
			//console.log( devices )
			Object.keys(hourly).forEach(function(k){
				//console.log(k, devices[k] )
				if(!monthly[k]){
					if(_unlimited_usage=='0'){
						monthly[k]={usage:[],down:0,up:0}
					}
					else{
						monthly[k]={usage:[],down:0,up:0,ul_down:0,ul_up:0}
					}
					cmu(k)
				}
				monthly[k].usage[dn].down+=hourly[k].down
				monthly[k].usage[dn].up+=hourly[k].up
				var gn=devices[k].cg
				if(!names[gn]){
					var n=Object.keys(names).length
					if(_unlimited_usage=='0'){
						names[gn]={n:n,group:devices[k].group,down:0,up:0,usage:[]}
					}
					else{
						names[gn]={n:n,group:devices[k].group,down:0,up:0,ul_down:0,ul_up:0,usage:[]}
					}
				}
				if(!names[gn].usage[dn]){
					names[gn].usage[dn]={down:0,up:0}
					if(_unlimited_usage=='1'){
						names[gn].usage[dn].ul_down=0
						names[gn].usage[dn].ul_up=0
					}
				}
				names[gn].usage[dn].down+=hourly[k].down
				names[gn].usage[dn].up+=hourly[k].up
				monthly_totals.down+=hourly[k].down
				monthly_totals.up+=hourly[k].up
				monthly_totals.usage[dn].down+=hourly[k].down
				monthly_totals.usage[dn].up+=hourly[k].up
				if(_unlimited_usage=='1'){
					monthly[k].usage[dn].ul_down+=hourly[k].ul_down
					monthly[k].usage[dn].ul_up+=hourly[k].ul_up
					names[gn].usage[dn].ul_down+=hourly[k].ul_down
					names[gn].usage[dn].ul_up+=hourly[k].ul_up
					monthly_totals.ul_down+=hourly[k].ul_down
					monthly_totals.ul_up+=hourly[k].ul_up
					monthly_totals.usage[dn].ul_down+=hourly[k].ul_down
					monthly_totals.usage[dn].ul_up+=hourly[k].ul_up
				}
				tmv(k)
			})
			var o2u=!!interfaces['br0']?interfaces['br0']:interfaces['br-lan']
			monthly_totals.pnd[dn]={down:o2u.down,up:o2u.up}
			$('.hwncd').show()
			var maxHr=today.getHours()
		}
		else{
			var maxHr=24
			$('.hwncd').hide()
		}
		updateDashboard()
		//To-do --> drawSummaryGauges() using the v3 data
		//drawSummaryGauges(disk_utilization, freeMem+','+availMem+','+totMem) // won't work for with v4 data files
		var cmo=_rs_Date.getMonth()*1
		if(_rs_Date.getDate()!=_ispBillingDay)cmo--
		var ry=_rs_Date.getFullYear(),rm=twod(cmo+1),rd=twod(_ispBillingDay),bill=ry+'-'+rm+'-'+rd,mts=monthly_totals.up+';'+monthly_totals.down
		if(_unlimited_usage=='1'){
			mts+=';'+monthly_totals.ul_up+';'+monthly_totals.ul_down
		}
		if(!g_Settings['summaries'])g_Settings['summaries']={}
		if(!g_Settings['history']){
			g_Settings['history']={}
		} 
		if(!g_Settings['history'][bill]){
			g_Settings['history'][bill]={}
		}
		g_Settings['summaries'][bill]=mts
		g_Settings['history'][bill]['down']=monthly_totals.down
		g_Settings['history'][bill]['up']=monthly_totals.up
		if(_unlimited_usage=='1'){
			g_Settings['history'][bill]['ul_down']=monthly_totals.ul_down
			g_Settings['history'][bill]['ul_up']=monthly_totals.ul_up
		}
		if(monthlyDataCap==null && g_Settings['history'][bill]['monthlyDataCap']==null){
			monthlyDataCap = prompt('Enter the cap for this month:', 0)
			g_Settings['history'][bill]['monthlyDataCap']=monthlyDataCap
		}
		else if(g_Settings['history'][bill]['monthlyDataCap']==null){
			g_Settings['history'][bill]['monthlyDataCap']=monthlyDataCap
		}
		saveSettings()

		setSummaryTotals()
		nHourlyReadFailures=0

		loadView(true)
		changelegend()
		var restartStr='',comma=''
		for(var x=0;x<maxHr;x++){
			if(!pnd_data||!pnd_data.usage||!pnd_data.usage[x*1]||pnd_data.usage[x*1].restarted){
				restartStr+=comma+x+'-'+(x+1)
				comma=','
			}
		}
		for(var x=1;x<maxHr;x++){
			restartStr=restartStr.replace('-'+x+','+x,'');
		}
		(restartStr!='')&&($('#ShowRD').is(':checked'))&&ShowAlert("<p>Your <a href='"+datafile+"' target='_blank'>Hourly usage file</a> is missing some or all of the `measured at the router` data "+(isToday?'today': 'on '+formattedDate(_cr_Date))+" during the hours: "+restartStr+".</p><p>This could be caused by your internet connection being down,your router being restarted and/or the YAMon script not running.</p>",'missing')
		var sel=$("#mb-filter").val()
		$("#mb-filter").html('<option value="ALL" selected>ALL Traffic By Day</option>')
		Object.keys(devices).sort(byName).forEach(function(d){
			if(!monthly[d]) return
			var id=devices[d].id,u_n=devices[d].cg,ud=devices[d].name,u_d=devices[d].cn, gp=devices[d].cg
			$("#mb-filter").append($("<option/>").attr('id','mbd-'+d).attr('title',d.toUpperCase()+' | '+devices[d].ip).attr('data-gp',gp).attr('value','dd-'+gp+'-'+u_d).text(ud).addClass('ddl-d du-'+u_n))
		})
		Object.keys(names).forEach(function(n){
			if(names[n].down==0 && names[n].up==0) return
			$(".du-"+n).first().before($("<option/>").attr('id','mbd-'+n).attr('value','dd-'+n).text(names[n].group).addClass('ddl-u du-'+n))
		})
		$("#mb-filter").val(sel)

		clearLoading()
		var dii=Math.floor((_re_Date-_rs_Date)/(1000*60*60*24)), cdii=Math.floor((_cr_Date-_rs_Date)/(1000*60*60*24))
		$( ".report-date" ).slider('option','max',dii)
		$( ".report-date" ).slider('option','value',cdii)
		var cw=$('.current-date').textWidth(),mw=$('.sp-current-date').width()-_slider_right,nd=$('.report-date').slider('option','max')-1,os=(mw-cw)/dii+_slider_left
		$('.sp-current-date').css('text-indent',os*cdii)
		$('.unknown-mac').remove()
		$('#dt-UNKNOWN00MAC').addClass('p-r').append("<a class='alert unknown-mac' href='http://usage-monitoring.com/help/?t=unknown-mac' target='_blank' title='Click to find out why this is here?!?'>Huh?!?</a>")
		$('.pDBtn').first().clone(true, true).appendTo('.graphdiv')
		$('.nDBtn').first().clone(true, true).appendTo('.graphdiv')
		deferred.resolve()
	})
	.fail(function(jqxhr,settings,exception){
		nHourlyReadFailures++
		var msg='<p>Error #'+nHourlyReadFailures+' reading the hourly data file: `<a href="'+datafile+'" target="_blank">'+datafile+'</a>`\n'+exception+'</p>'
		if(nHourlyReadFailures>1){
			ShowAlert(msg,'hourly-error')
			showLoading("Could not open the hourly data file?!?  "+exception,'failed')
			clearLoading(3000)
			nHourlyReadFailures=0
			clearInterval(refreshTimer)
			deferred.fail()
			return false
		}
		else{
			setTimeout(function(){var hourlyLoaded = loadHourly()},1000)
			return false
		}
		loadView(cleardata)
		changelegend()
	})
 	return deferred.promise()
}
function loadView(cleardata){
	$('.current-interval').addClass('loading')
	var cvs=$('.selected').attr('id'),cs=$('#'+cvs+'-section')
	if (!cvs=='live-tab') clearInterval(liveUpdatesTimer)
	if ($('#'+cvs).hasClass('loaded')){
		return
	}
	switch(cvs){
		case 'summary-tab': 
			var notdefined='Not defined... rerun setup!'
			$('.router-brand').text((typeof(_router)==='undefined' || _installed=='')?notdefined:_router)
			$('.router-firmware').text((typeof(_firmwareName)==='undefined' || _installed=='')?notdefined:_firmwareName)
			$('.router-installed').text((typeof(_installed)==='undefined' || _installed=='')?notdefined:_installed)
			$('.router-updated').text((typeof(_updated)==='undefined' || _updated=='')?'TBD':_updated)

			break;
		case 'daily-tab':
			if(cleardata){
				$('#DailyData .is_d').addClass('clear')
			}
			setDailyTab()
			break;
		case 'monthly-tab':
			if(cleardata){
				$('#MonthlyData').html('')
				//$('#MonthlyData .is_d').addClass('clear')
			}
			setMonthlyTab()
			break;
		case 'monthly-breakdown-tab':
			if(cleardata){
				$('#MonthlyBreakdown').html('')
			}
			setMonthlyBreakdown()
			break;
		case 'live-tab':
			if(_doLiveUpdates=='1'){
				setLiveUpdates()
				clearInterval(liveUpdatesTimer);
				liveUpdatesTimer=setInterval(setLiveUpdates,1000*_updatefreq)
			}
			break;
		case 'devices-tab':
			if(cleardata){
				$('#devicesData').html('')
			}
			setDevices()
			break;
	}
	showHideDevices()
	$('#devicesData tr:visible:odd').addClass('odd')
	cs.siblings('.tab-div').slideUp('fast')
	cs.fadeIn('slow')
	$('#'+cvs).addClass('loaded')
	updateGraphs(cvs)
	$('.current-interval').removeClass('loading')
	$('.pDBtn').first().clone(true, true).appendTo('#daily-tab-section .graphdiv')
	$('.nDBtn').first().clone(true, true).appendTo('#daily-tab-section .graphdiv')

}
function updateGraphs(cvs){
	switch(cvs){
		case 'summary-tab':
			UsageHistoryChart()
			break;
		case 'daily-tab':
			DrawPie('Daily')
			DrawHourlyGraph()
			DrawCandle()
			DrawInterfacesGraph()
			break;
		case 'monthly-tab':
			DrawPie('Monthly')
			DrawMonthlybyDeviceGraph()
			_unlimited_usage=='1' && DrawPie('Unlimited')
			break;
		case 'monthly-breakdown-tab':
			drawGraphs()
			break;
	}
}
//----------- loadDevices -------------
function ud_a(arr){
	var mac=arr.mac.toLowerCase()+(!arr.key?'':('-'+arr.key))
	if(!g_Settings['devices']||!g_Settings['devices'][mac]){
		var group=arr.owner,name=arr.name,colour=arr.colour
	}
	else if(arr.owner==g_Settings['devices'][mac].group && arr.name==g_Settings['devices'][mac].name && arr.colour==g_Settings['devices'][mac].colour){
		var group=arr.owner,name=arr.name,colour=arr.colour
		delete g_Settings['devices'][mac]
		saveSettings()
	}
	else{
		var group=g_Settings['devices'][mac].group,name=g_Settings['devices'][mac].name,colour=g_Settings['devices'][mac].colour
	}
	var lgroup=clean(group), cn=clean(name), n
	var uid=mac.replace(/:/g,"")
	var ip4=arr.ip=='0.0.0.0/0'?'0.0.0.0_0':arr.ip
	n=!devices[mac]?Object.keys(devices).length:devices[mac].n
	var ip6=arr.ip6=='0/0'?'0_0':arr.ip6
	var ls=arr['last-seen']||''
	var dih=!g_Settings['devices'][mac]?false:(g_Settings['devices'][mac].hidden||false)
	devices[mac]={n:n,id:uid,ip:ip4,ip6:ip6,group:group,cg:lgroup,name:name,cn:cn,colour:colour,added:arr.added,updated:arr.updated,last_seen:ls,hidden:dih}
	if(!names[lgroup]){
		var n=Object.keys(names).length
		if(_unlimited_usage=='0'){
			names[lgroup]={n:n,group:group,down:0,up:0,usage:[]}
		}
		else{
			names[lgroup]={n:n,group:group,down:0,up:0,ul_down:0,ul_up:0,usage:[]}
		}
	}
}
//----------- loadMonthly -------------

function testReportDates(){
	_ispBillingDay=29

	var d=new Date("2020-1-1"), m1=d.getMonth()
	var n=1, pem
	console.clear()
	while(n<365){
		var da=d.getDate()*1, mo=d.getMonth()*1+1, yr=d.getFullYear() 
		var em=da<_ispBillingDay?mo-1:mo
		var fdoi1=new Date(yr, em, 1), fdoi2=new Date(yr, em-1, _ispBillingDay) 
		var fdoi=new Date(Math.min(fdoi1, fdoi2)) 

		var ldoi1=new Date(yr, em+1, 0), ldoi2=new Date(yr, em, _ispBillingDay-1) 
		var ldoi=new Date(Math.min(ldoi1, ldoi2))
		pem=em
		n++
		d=new Date(yr,m1,n)
	}

}
function setReportDates(ri){
	var da,mo,yr
	if(!ri){
		$('#p-timer').fadeIn('slow')
		_cr_Date=new Date(), da=_cr_Date.getDate()*1, mo=_cr_Date.getMonth()*1+1, yr=_cr_Date.getFullYear()
		var em=da<_ispBillingDay?mo-1:mo
		var ldom_p=new Date(yr,mo,0).getDate(), ldom_c=new Date(yr,mo+1,0).getDate()
		var fdoi1=new Date(yr, em, 1), fdoi2=new Date(yr, em-1, _ispBillingDay) 
		_rs_Date=new Date(Math.min(fdoi1, fdoi2)) 
		
		var ldoi1=new Date(yr, em+1, 0), ldoi2=new Date(yr, em, _ispBillingDay-1) 
		_re_Date=new Date(Math.min(ldoi1, ldoi2))
		//console.log ( _cr_Date, da,_ispBillingDay, mo, em, _rs_Date, ' - ', _re_Date)
	}
	else{
		var de=ri.split('-')
		da=twod(de[2])
		mo=twod(de[1])
		yr=de[0]
		_rs_Date= new Date(yr,mo-1,da)
		_re_Date=new Date(yr,mo,da-1)
		_cr_Date=_rs_Date
	}
	$('.rs-date').text(formattedDate(_rs_Date))
	$('.re-date').text(formattedDate(_re_Date))
	$('.current-date').text(formattedDate(_cr_Date))
	$('.current-interval').text(formattedDate(_rs_Date,3)+' - '+formattedDate(_re_Date,3))
	var dii=Math.floor((_re_Date-_rs_Date)/(1000*60*60*24)),cdii=Math.floor((_cr_Date-_rs_Date)/(1000*60*60*24))
	$('.report-date').slider('option','max',dii)
	$('.report-date').slider('option','value',cdii)
	var cw=$('.current-date').textWidth(),mw=$('.sp-current-date').width()-_slider_right,os=(mw-cw)/dii+_slider_left
	$('.sp-current-date').css('text-indent',os*cdii)
}
function dtp(arr){
	monthly_totals.pnd[arr.day*1]={down:arr.down,up:arr.up}
	monthly_totals.pnd[arr.day*1].reboots=arr.reboots||0
}
function dt(arr){
	var mac=arr.mac.toLowerCase()
	if(mac=='FF:FF:FF:FF:FF:FF') return;
	check4Device(mac)
	var group=devices[mac].cg,dn=arr.day*1
	if(!names[group]){
		var n=Object.keys(names).length
		if(_unlimited_usage=='0'){
			names[group]={n:n,group:arr.owner,down:0,up:0,usage:[]}
		}
		else{
			names[group]={n:n,group:arr.owner,down:0,up:0,ul_down:0,ul_up:0,usage:[]}
		}
	}
	if(!names[group].usage[dn]){
		if(_unlimited_usage=='0'){
			names[group].usage[dn]={down:0,up:0}
		}
		else{
			names[group].usage[dn]={down:0,up:0,ul_down:0,ul_up:0}
		}
	}
	var down=arr.down*1,up=arr.up*1
	monthly[mac].down+=down
	monthly[mac].up+=up
	names[group].down+=down
	names[group].up+=up
	monthly_totals.down+=down
	monthly_totals.up+=up
	monthly[mac].usage[dn]={down:down,up:up}
	names[group].usage[dn].down+=down
	names[group].usage[dn].up+=up
	monthly_totals.usage[dn].down+=down
	monthly_totals.usage[dn].up+=up
	if(_unlimited_usage=='1'){
		var ul_down=arr.ul_do*1||0,ul_up=arr.ul_up*1||0
		monthly[mac].ul_down+=ul_down
		monthly[mac].ul_up+=ul_up
		names[group].ul_down+=ul_down
		names[group].ul_up+=ul_up
		monthly_totals.ul_down+=ul_down
		monthly_totals.ul_up+=ul_up
		monthly[mac].usage[dn].ul_down=ul_down
		monthly[mac].usage[dn].ul_up=ul_up
		names[group].usage[dn].ul_down+=ul_down
		names[group].usage[dn].ul_up+=ul_up
		monthly_totals.usage[dn].ul_down+=ul_down
		monthly_totals.usage[dn].ul_up+=ul_up
   }
}
function check4Device(mac){
	if (!devices[mac]){
		var uid=mac.replace(/:/g,"")
		var dt=new Date(),dts=dt.getFullYear()+'-'+twod(dt.getMonth()+1)+'-'+twod(dt.getDate())+' '+twod(dt.getHours())+'-'+twod(dt.getMinutes())+'-'+twod(dt.getSeconds())
		var n=Object.keys(devices).length, group='Unknown', cg=clean(group), name='new device - '+mac,cn=clean(name)
		devices[mac]={n:n,id:uid,group:group,cg:cg,colour:'',name:name,cn:cn,added:dts,updated:dts}
		if(!names['unknown']){
			var n=Object.keys(names).length
			if(_unlimited_usage=='0'){
				names['unknown']={n:n,group:'Unknown',down:0,up:0,usage:[]}
			}
			else{
				names['unknown']={n:n,group:'Unknown',down:0,up:0,ul_down:0,ul_up:0,usage:[]}
			}
		}
	}
	if(!monthly[mac]){
		if(_unlimited_usage=='0'){
			monthly[mac]={down:0,up:0,usage:[]}
		}
		else{
			monthly[mac]={down:0,up:0,ul_down:0,ul_up:0,usage:[]}
		}
		cmu(mac)
	}
}
function cmu(mac){
	if(_unlimited_usage=='0'){
		monthly[mac]={down:0,up:0,usage:[]}
		for(var x=1;x<32;x++){
			monthly[mac].usage[x]={down:0,up:0}
		}
	}
	else{
		monthly[mac]={down:0,up:0,ul_down:0,ul_up:0,usage:[]}
		for(var x=1;x<32;x++){
			monthly[mac].usage[x]={down:0,up:0,ul_down:0,ul_up:0}
		}
	}
}
//----------- loadHourly -------------
function serverloads(minL,minTS,maxL,maxTS){
	minL*=1
	maxL*=1
	var _processors=1
	var gw=$('.gradient').css('width').replace('px','')*1 ,wm=gw/Math.max(_processors,$('#sp_15minSL .txt').text()*1)
	var los=Math.max(22,$('.gradient').position()['left']*1)
	$('#serverload').fadeIn('slow')
	$('#sp_5minSL').attr('title','Min load at: '+minTS)
	$('#sp_5minSL .txt').text(minL.toFixed(2))
	$('#sp_15minSL').attr('title','Max load at: '+maxTS)
	$('#sp_15minSL .txt').text(maxL.toFixed(2))
	var l1=Math.min(gw, minL*wm-Math.max(20,$('#sp_5minSL').width())/2)+los,l2=Math.min(gw, maxL*wm-Math.max(20,$('#sp_15minSL').width())/2)+los
	$('#sp_5minSL').css('left',l1)
	$('#sp_15minSL').css('left',l2)
}
function hu(arr){
	var mac=arr.mac.toLowerCase()
	check4Device(mac)
	if(!hourly[mac]){
		hourly[mac]={usage:[],down:0,up:0}
		chu(mac)
	}
	var hr=arr.hour*1,down=arr.down*1,up=arr.up*1
	if (!hourly_totals.usage[hr]) hourly_totals.usage[hr]={down:0,up:0}
	hourly[mac].down+=down
	hourly[mac].up+=up
	hourly[mac].usage[hr].down+=down
	hourly[mac].usage[hr].up+=up
	if(_unlimited_usage=='1'){
		var ul_do=arr.ul_do*1||0,ul_up=arr.ul_up*1||0
		hourly[mac].ul_down+=(ul_do)
		hourly[mac].ul_up+=(ul_up)
		hourly[mac].usage[hr].ul_down+=(ul_do)
		hourly[mac].usage[hr].ul_up+=(ul_up)
	}
	hourly_totals.down+=down
	hourly_totals.up+=up
	hourly_totals.usage[hr].down+=down
	hourly_totals.usage[hr].up+=up
}
function chu(mac){
	hourly[mac].down=0
	hourly[mac].up=0
	if(_unlimited_usage=='0'){
		for(var hr=0;hr<24;hr++){
			hourly[mac].usage[hr]={down:0,up:0}
		}
	}
	else{
		hourly[mac].ul_down=0
		hourly[mac].ul_up=0
		for(var hr=0;hr<24;hr++){
			hourly[mac].usage[hr]={down:0,up:0,ul_down:0,ul_up:0}
		}
	}
}

function pnd(arr){
	if(!arr.uptime && !arr["hr-loads"]) return
	var sut=!arr.uptime?null:arr.uptime
	if(arr.hour=='start'){
		pnd_data={start:{down:!sut?0:arr.down,up:!sut?0:arr.up},total:{down:0,up:0,dropped:0,lost:0,local:0},usage:{}}
		p_pnd_d=arr.down
		p_pnd_u=arr.up
		p_dropped=(!arr.iptables)||(!arr.iptables.DROP)?0:arr.iptables.DROP
		p_local=(!arr.iptables)||(!arr.iptables.p_local)?0:arr.iptables.local
		o_sut=arr.uptime
		return
	}
	var svd=!sut?0:arr.down-p_pnd_d,svu=!sut?0:arr.up-p_pnd_u
	if(sut>o_sut||!o_sut){
		if(svd<0) svd+=Math.pow(2,32)-1
		if(svu<0) svu+=Math.pow(2,32)-1
		//pnd_data.usage[arr.hour*1]={down:svd,up:svu,lost:wl,dropped:sdr,local:loc}
		pnd_data.usage[arr.hour*1]={down:svd,up:svu}
	}
	else{
		svd=arr.down
		svu=arr.up
		pnd_data.usage[arr.hour*1]={down:svd,up:svu,restarted:true}
	}
	if(!arr['hr-loads']){}
	else{
		var hl=[arr.hour]
		hourlyloads[hl]=arr['hr-loads']
	}
	pnd_data.total.down+=svd
	pnd_data.total.up+=svu
	p_pnd_d=arr.down
	p_pnd_u=arr.up
	o_sut=arr.uptime
}
function tmv(m){
	var td=0,tu=0,tud=0,tuu=0
	for(var x=1;x<32;x++){
		if (!monthly[m].usage[x]) continue
		td+=monthly[m].usage[x].down
		tu+=monthly[m].usage[x].up
		tud+=monthly[m].usage[x].ul_down||0
		tuu+=monthly[m].usage[x].ul_up||0
	}
	monthly[m].down=td
	monthly[m].up=tu
	monthly[m].ul_down=tud
	monthly[m].ul_up=tuu
}
function setSummaryTotals(){
	flushChanges()
	var report=g_Settings['summaries']||{},bw_cap=((!monthlyDataCap || monthlyDataCap==0)?1000:monthlyDataCap)*g_toGB,dlo=$('#cb-dl-o').is(':checked')
	$('.tot-dlo').html(dlo?'Downloads<br/>Only':('Totals' +(_unlimited_usage=='0'?'':(' ('+($('#ul-redtot').is(':checked')?'less':'including') + ' Bonus Data)'))))
	var ul_redtot=$('#ul-redtot').is(':checked')?1:0
	var cTB=$('.currentSummary .tByts ').data('value')
	Object.keys(report).sort(byDate).forEach(function(bill){
		if (!report[bill])return
		if(bill.split('-')[0]=='NaN'){
			delete g_Settings['summaries'][bill]
			saveSettings()
			return
		}
		var values=report[bill].split(';')
		var up=values[0]*1,down=values[1]*1
		if(_unlimited_usage=='1'){
			var ul_up=values[2]*1||0,ul_dn=values[3]*1||0
			up-=(ul_up)*ul_redtot
			down-=(ul_dn)*ul_redtot
		}
		if($("#"+bill).length==0){
			var nr=$('#blank-summary-row').clone(true,true).attr('id',bill).addClass('summary-row').removeClass('hidden')
			nr.find('.interval').text(bill)
			nr.appendTo('#SystemTotalsTable')
		}
		var arr=[[' .downloads',down],[' .uploads',up],[' .tByts',dlo?down:(up+down)]]
		updateRow('#'+bill,arr)
	})
	var nTB=$('.currentSummary .tByts ').data('value')
	if((nTB!==cTB)&&($('.currentSummary').attr('id')!=$('.summary-row').first().attr('id'))) saveSettings()
	var today=new Date()
	if(_cr_Date!=_rs_Date && _cr_Date.toDateString()==today.toDateString()){
		var bps=$('.summary-row').first().find('.tByts').data('value')/((_cr_Date-_rs_Date))
		var etb=bps*((_re_Date-_rs_Date))
		$('.summary-row').first().find('td').last().data('value',etb).addClass('num').attr('id','estimatedMonthlyTotal').attr('title','Projected monthly total ')
		if($('#estimatedMonthlyTotal').data('value')>Number($('#spUsageCap').text())*g_toGB){
			$('#estimatedMonthlyTotal').addClass('over-cap')
		}
	}
	$('.is-cap')[(!monthlyDataCap || monthlyDataCap==0)?'hide':'show']()
	setPercents('.summary-row',bw_cap)
	displayBytes('#SystemTotalsTable,#SummaryUsageTable')
	$('.interval').unbind('click').click(function(){
		if($(this).parents('tr').hasClass('currentSummary')) return(false)
		$('.currentSummary').removeClass('currentSummary')
		$(this).parents('.summary-row').addClass('currentSummary')
		var monthlyLoaded = loadMonthly();
		monthlyLoaded.done(function(){
			var hourlyLoaded = loadHourly()
			hourlyLoaded.done(function(){
			});
		});
	})
	if(!$('.currentSummary').length) $('.summary-row').first().addClass('currentSummary')
	$('.nmBtn')[$('.currentSummary').is(':first-child')?'addClass':'removeClass']('disabled')
	clearInterval(refreshTimer)
	if($('.currentSummary').is(':first-child'))
		refreshTimer=setInterval(refreshTimerFunc,1000)
}
function UsageHistoryChart(){
	$('#UsageGraph').slideDown('slow')
	var data;
	data=new google.visualization.DataTable()
	data.addColumn('string','Billing Interval')
	data.addColumn('number','Downloads')
	data.addColumn('number','Uploads')
	data.addColumn('number','Projected')
	data.addColumn('number','Usage Allowance')
	var cap=(!monthlyDataCap || monthlyDataCap==0)?1000:monthlyDataCap*1
	$('.summary-row').each(function(){
		var t=$(this).attr('id').split('-')
		var cI=t[0]+'-'+t[1]
		var up=Number(($(this).find('.uploads').data('value')/g_toGB).toFixed(_dec))
		var down=Number(($(this).find('.downloads').data('value')/g_toGB).toFixed(_dec))
		var proj=$(this).is(':first-child')?(($('#estimatedMonthlyTotal').data('value')-$('.summary-row:first .tByts ').data('value'))/g_toGB).toFixed(_dec)*1:null
		data.addRow([cI,down,up,proj,cap])
	})
	var ht=Math.max(275,$('#SystemTotalsTable').height())
	var baroptions={
		width:456,height:ht,seriesType: "bars",title:'Monthly Utilization',legend:{position:'top',textStyle: {color: 'black',fontSize: 10}},backgroundColor: { fill:inDarkMode?darkmodeBG:'transparent'},chartArea:{width:'80%',height:'66%'},isStacked:true,hAxis:{direction:-1,title:'Month',slantedText:true,titleTextStyle:{color:'green'},textStyle:{fontSize:9}},vAxis:{title:'GB',titleTextStyle:{color:'green'}},series:{0:{color:'blue',visibleInLegend:true},1:{color:'green',visibleInLegend:true},2:{color:'lightPink',visibleInLegend:true},3:{type: "line",color:'red',lineWidth:1,visibleInLegend:true}}
	};
	var UsageChart=new google.visualization.ColumnChart(document.getElementById('UsageGraph'))
	UsageChart.draw(data,baroptions)
}
//----------------- loadView ------------------------
function setDailyTab(){
	var ul_redtot=$('#ul-redtot').is(':checked')?1:0
	var total=0,utot=0,dtot=0,ul_utot=0,ul_dtot=0
	var cd=_cr_Date.getDate()
	if(!corrections||!corrections[cd]){
		$('#correction-row,#remove-correction').hide()
		var cdu=0,cdd=0,cddesc=''
		var has_corr=0
		$('#add-correction').slideDown('slow')
	}
	else{
		$('#correction-row,#remove-correction').show()
		$('#add-correction').hide()
		var cddesc=corrections[cd].desc,cdu=corrections[cd].up,cdd=corrections[cd].down
		var has_corr=1
		utot=cdu*g_toMB
		dtot=cdd*g_toMB
		total=utot+dtot
	}
	$('.cf-desc').text(cddesc)
	$('#cf-desc').val(cddesc)
	$('.cf-u').attr('value',cdu*g_toMB)
	$('.cf-d').attr('value',cdd*g_toMB)
	$('#cf-u').val(cdu)
	$('#cf-d').val(cdd)
	$('#correction-row .tByts').data('value',total)
	$('#DailyData .is_z').removeClass('is_z')
	$('#Daily-usage-table .num').each(function(){
		$(this).data('value', 0)
	})
	$('#DailyData .is_d').addClass('clear')
	var inc_isp=$('#showISP').is(':checked'),inc_rd=$('#ShowRD').is(':checked'),arr
	Object.keys(hourly).sort(byGN).forEach(function(k){
		var did='dt-'+devices[k].id
		var gn=devices[k].cg,gid='gp-'+gn,ddn=devices[k].cn
		var up=hourly[k].up*1,down=hourly[k].down*1,ut=up+down
		if(_unlimited_usage=='1'){
			var ul_up=hourly[k].ul_up*1,ul_down=hourly[k].ul_down*1,ut=up+down-(ul_up+ul_down)*ul_redtot
		}
		total+=ut
		utot+=up
		dtot+=down
		ul_utot+=ul_up
		ul_dtot+=ul_down
		if($("#"+gid).length==0){
			var nr=$('#blank-group-row').clone(true,true).detach().attr('id',gid).attr('data-g-n',gn).addClass('is_u').removeClass('hidden')
			nr.find('.userName').text(devices[k].group)
			nr.appendTo('#DailyData')
			arr=[[' .downloads',down],[' .uploads',up],[' .ul-down',ul_down],[' .ul-up',ul_up],[' .tByts',ut]]
		}
		else{
			var gdown=down+$("#"+gid).find('.downloads').data('value')*1,
				gup=up+$("#"+gid).find('.uploads').data('value')*1,
				gul_down=(ul_down+$("#"+gid).find('.ul-down').data('value')*1)||0,
				gul_up=(ul_up+$("#"+gid).find('.ul-up').data('value')*1)||0,
				gut=gup+gdown-(gul_up+gul_down)*ul_redtot
			arr=[[' .downloads',gdown],[' .uploads',gup],[' .ul-down',gul_down],[' .ul-up',gul_up],[' .tByts',gut]]
		}
		updateRow('#'+gid,arr)
		if($("#"+did).length==0){
			var nr=$('#blank-device-row').clone(true,true).detach().attr('id',did).attr('data-mac',k).attr('data-g-n',gn+'-'+ddn).addClass('is_d '+gid).data('group',devices[k].group).removeClass('hidden')
			var tcolour=devices[k].colour==''?colours_list[devices[k].n%n_colours]:devices[k].colour
			nr.find('.legend-colour').css('background-color',tcolour)
			nr.find('.deviceName').attr('title',k.toUpperCase()+' | '+devices[k].ip)
			nr.find('.thedevice').text(devices[k].name)
			nr.insertAfter('#'+gid)
		}
		arr=[[' .downloads',down],[' .uploads',up],[' .ul-down',ul_down],[' .ul-up',ul_up],[' .tByts',ut]]
		updateRow('#'+did,arr)
	})
	$('.is_u.odd').removeClass('odd')
	var arr=[[' .downloads',dtot],[' .uploads',utot],[' .ul-down',ul_dtot],[' .ul-up',ul_utot],[' .tByts',total]]
	updateRow('.DailyFooter',arr)
	$('thead .DailyFooter')[g_Settings['DupTotals']?'show':'hide']()
	var o2u=!!interfaces['br0']?interfaces['br0']:interfaces['br-lan']
	if(!o2u){
		$('#RouterFooter,#DiffFooter,#PercentFooter,#LocalFooter').hide()
	}
	else if(o2u.up==0&&o2u.down==0){
		$('#RouterFooter,#DiffFooter,#PercentFooter').hide()
	}
	else{
		var arr=[[' .downloads',pnd_data.total.local||0],[' .uploads',0],[' .tByts',pnd_data.total.local||0]]
		updateRow('#LocalFooter',arr)

		$('#RouterFooter,#DiffFooter,#PercentFooter')[inc_rd?'show':'hide']()
		arr=[[' .downloads',o2u.down],[' .uploads',o2u.up],[' .tByts',o2u.down+o2u.up]]
		updateRow('#RouterFooter',arr)
		$('#RouterFooter .percent').text(((o2u.down+o2u.up)/total*100-100).toFixed(_dec))
		arr=[[' .downloads',o2u.down-dtot],[' .uploads',o2u.up-utot],[' .tByts',o2u.down+o2u.up-total]]
		updateRow('#DiffFooter',arr)
		$('#PercentFooter .downloads').text(((o2u.down-dtot)/dtot*100).toFixed(_dec))
		$('#PercentFooter .uploads').text(((o2u.up-utot)/utot*100).toFixed(_dec))
		$('#PercentFooter .tByts').text(((o2u.down+o2u.up-total)/total*100).toFixed(_dec))
	}
	$('#h_sd-dd,#h_sd-ddl, #submenu').remove()
	$('#c-h_sd').append("<span id='submenu'><span id='h_fd-all' class='h_fd'>All</span><span id='h_fd-none' class='h_fd'>None</span></span>")
	$('#DailyData .userName').each(function(){
		$('#submenu').append("<span class='h_fd'>"+$(this).text()+"</span>")
	})
	$('.item-e')[$('#ShowDevices').is(':checked')?'removeClass':'addClass']('item-c')
	$('.h_fd').click(function(){
		var un=$(this).text().toLowerCase()
		$('.fd-sel, .fd-some').removeClass('fd-sel fd-some')
		$(this).addClass('fd-sel')
		$('#h_sd')[un=='all'?'addClass':'removeClass']('checked')
		ShowDevices(un)
	})
	if($('#DailyData .is_d').length>0 && $('#DailyData .is_d').length-$('#DailyData .gp-unknown').length==0){
		ShowAlert("<p>It appears that all of your devices have been added as `New/unknown` devices</p><p>If you've just started running YAMon,you can now go to the `Devices` tab and customize the owners & names for the devices on your network.</p>",'devices-error')
	}
	if(inc_isp){
		var cd=_cr_Date.getDate(),mo=twod(_rs_Date.getMonth()+1),yr=_rs_Date.getFullYear()
		if(!g_Settings['isp'][mo+'-'+yr]){
			var isp_totals={}
		}
		else{
			var isp_totals=JSON.parse(g_Settings['isp'][mo+'-'+yr])
		}
		if(!isp_totals[cd]){
			$('#d-isp-d,#d-isp-u').val(0)
			$('.d-isp-d,.d-isp-u').data('value',0)
			$('#daily-isp-row .tByts').data('value',0)
			$('#daily-isp-row .percent').text('')
			$('#daily-isp-diff,#daily-isp-percent').hide()
		}
		else{
			var isp_d=isp_totals[cd].down*1,isp_u=isp_totals[cd].up*1
			$('#d-isp-d').val(isp_d/g_toMB)
			$('#d-isp-u').val(isp_u/g_toMB)
			$('.d-isp-d').data('value',isp_d)
			$('.d-isp-u').data('value',isp_u)
			$('#daily-isp-row .tByts').data('value',isp_d+isp_u)
			$('#daily-isp-row .percent').text(((isp_d+isp_u-total)/total*100).toFixed(_dec))
			$('#daily-isp-row,#daily-isp-diff,#daily-isp-percent').show()
			arr=[[' .downloads',isp_d-dtot],[' .uploads',isp_u-utot],[' .tByts',isp_d+isp_u-total]]
			updateRow('#daily-isp-diff',arr)
			$('#daily-isp-percent .downloads').text(((isp_d-dtot)/dtot*100).toFixed(_dec))
			$('#daily-isp-percent .uploads').text(((isp_u-utot)/utot*100).toFixed(_dec))
			$('#daily-isp-percent .percent:last').text(((isp_d+isp_u-total)/total*100).toFixed(_dec))
		}
	}
	else{
		$('#Daily-usage-table .is-isp').hide()
	}
	$('#DailyData .is_u').each(function(){
		if ($(this).find('.tByts').data('value')==0) $(this).slideUp('slow')
	})

	$('.d-ng').text($('#DailyData .is_u').length)
	$('.d-nd').text($('#DailyData .is_d').length)
	$('.isUL')[_unlimited_usage=='1'?'removeClass':'addClass']('hidden')
	$('#DailyData .clear').slideUp('slow')
	hourlyTable()
	setPercents('#DailyData tr,#correction-row',total)
	displayBytes('#Daily-usage-table, #hourly-table')
}
function setMonthlyTab(){
	var ul_redtot=$('#ul-redtot').is(':checked')?1:0
	$('#MonthlyData .is_u').each(function(){
		var gid=$(this).attr('id'),arr=[[' .downloads',0],[' .uploads',0],[' .ul-down',0],[' .ul-up',0],[' .tByts',0]]
		updateRow('#'+gid,arr)
	})
	var total=0,utot=0,dtot=0,ul_utot=0,ul_dtot=0
	var inc_isp=$('#showISP').is(':checked')
    $('#Monthly-usage-table .num').each(function(){
		$(this).data('value', 0)
	})
	Object.keys(monthly).sort(byGN).forEach(function(k){
		var did='mt-'+devices[k].id
		var gn=devices[k].cg,gid='mgp-'+gn,ddn=devices[k].cn
		var up=monthly[k].up*1,down=monthly[k].down*1,ul_up=0,ul_down=0,ut=up+down
		if(_unlimited_usage=='1'){
			var ul_up=monthly[k].ul_up*1,ul_down=monthly[k].ul_down*1,ut=up+down-(ul_up+ul_down)*ul_redtot
		}
		total+=ut
		utot+=up
		dtot+=down
		ul_utot+=ul_up
		ul_dtot+=ul_down
		if($("#"+gid).length==0){
			var nr=$('#blank-group-row').clone(true,true).off('click').off('dblclick').detach().attr('id',gid).attr('data-g-n',gn).addClass('is_u').removeClass('hidden')
			nr.find('.userName').text(devices[k].group)
			nr.appendTo('#MonthlyData')
			arr=[[' .downloads',down],[' .uploads',up],[' .ul-down',ul_down],[' .ul-up',ul_up],[' .tByts',ut]]
		}
		else{
			var gdown=down+$("#"+gid).find('.downloads').data('value')*1,gup=up+$("#"+gid).find('.uploads').data('value')*1,gul_down=ul_down+($("#"+gid).find('.ul-down').data('value')||0)*1,gul_up=ul_up+($("#"+gid).find('.ul-up').data('value')||0)*1,gut=gup+gdown-(gul_up+gul_down)*ul_redtot
			arr=[[' .downloads',gdown],[' .uploads',gup],[' .ul-down',gul_down],[' .ul-up',gul_up],[' .tByts',gut]]
		}
		updateRow('#'+gid,arr)
		if($("#"+did).length==0){
			var nr=$('#blank-device-row').clone(true,true).detach().attr('id',did).attr('data-mac',k).attr('data-g-n',gn+'-'+ddn).addClass('is_d '+gid).data('group',devices[k].group).removeClass('hidden')
			var tcolour=devices[k].colour==''?colours_list[devices[k].n%n_colours]:devices[k].colour
			nr.find('.legend-colour').css('background-color',tcolour).off('click').off('dblclick')
			nr.find('.deviceName').attr('title',k.toUpperCase()+' | '+devices[k].ip).off('click').off('dblclick')
			nr.find('.thedevice').text(devices[k].name)
			nr.insertAfter('#'+gid)
		}
		arr=[[' .downloads',down],[' .uploads',up],[' .ul-down',ul_down],[' .ul-up',ul_up],[' .tByts',ut]]
		updateRow('#'+did,arr)
	})
	//$('#MonthlyData').html($('#MonthlyData tr'))
	$('#MonthlyData .item-e')[$('#ShowDevices').is(':checked')?'removeClass':'addClass']('item-c')
	$('.is_u.odd').removeClass('odd')
	var arr=[[' .downloads',dtot],[' .uploads',utot],[' .ul-down',ul_dtot],[' .ul-up',ul_utot],[' .tByts',total]]
	updateRow('.MonthlyFooter',arr)
	$('thead .MonthlyFooter')[g_Settings['DupTotals']?'show':'hide']()
	if(inc_isp){
		var cd=_cr_Date.getDate(),mo=twod(_rs_Date.getMonth()+1),yr=_rs_Date.getFullYear()
		if(!g_Settings['isp'][mo+'-'+yr]){
			$('#m-isp-d').data('value',0)
			$('#m-isp-d').data('value',0)
			$('#monthly-isp-row .tByts').data('value',0)
			$('#monthly-isp-row .percent').text('')
		}
		else{
			var isp_totals=JSON.parse(g_Settings['isp'][mo+'-'+yr]),isp_d=0,isp_u=0,mt=$('tfoot .MonthlyFooter .tByts').data('value')
			Object.keys(isp_totals).forEach(function(d){
				isp_d+=isp_totals[d].down*1
				isp_u+=isp_totals[d].up*1
			})
			$('#m-isp-d').data('value',isp_d)
			$('#m-isp-u').data('value',isp_u)
			$('#monthly-isp-row .tByts').data('value',isp_d+isp_u)
			$('#monthly-isp-row .percent ').text(((isp_d+isp_u-mt)/mt*100).toFixed(_dec))
		}
	}
	$('.m-ng').text($('#MonthlyData .is_u').length)
	$('.m-nd').text($('#MonthlyData .is_d').length)
	$('#Monthly-usage-table .isUL')[_unlimited_usage=='1'?'removeClass':'addClass']('hidden')
	setPercents('#MonthlyData tr,#mcorrection-row',total)
	displayBytes('#Monthly-usage-table')
}
function setMonthlyBreakdown(){
	$("#mb-filter .ddl-d").each(function(){
	var mac=$(this).attr('id').split('-')[1]
		$(this)[!monthly[mac]?'hide':'show']()
	})
	var today=new Date()
	var mbfs=$("#mb-filter option:selected")
	if(mbfs.hasClass('ddl-d')){
		var mac=mbfs.attr('id').split('-')[1]
		var dataset=monthly[mac].usage
	}
	else if(mbfs.hasClass('ddl-u')){
		var name=mbfs.attr('id').split('-')[1]
		var dataset=names[name].usage
	}
	else{
		var dataset=monthly_totals.usage
	}
	var inc_all=$('#mb-filter').val()=='ALL',inc_isp=inc_all&&$('#showISP').is(':checked'),inc_rd=inc_all&&$('#ShowRD').is(':checked')
	var mo=twod(_rs_Date.getMonth()+1),yr=_rs_Date.getFullYear()
	if(!g_Settings['isp'][mo+'-'+yr]){
		var isp_totals={}
	}
	else{
		var isp_totals=JSON.parse(g_Settings['isp'][mo+'-'+yr])
	}
	var cTot=0,tup=0
	var dtot=0,utot=0,ul_dtot=0,ul_utot=0,isp_d=0,isp_dd=0,isp_dp=0,isp_u=0,isp_ud=0,isp_up=0,isp_dct=0,isp_uct=0,isp_t,isp_td,isp_tp,isp_dv=0,isp_uv=0,isp_tv=0,isp_rtv=0,isp_ct=0,isp_rct=0
	var rd_d=0,rd_u=0,rd_dv=0,rd_uv=0,rd_dct=0,rd_uct=0,rd_tv=0,rd_ct=0,rd_fdt=0,rd_fut=0,rd_ft=0,isp_fdt=0,isp_fut=0,isp_ft=0
	var ul_redtot=$('#ul-redtot').is(':checked')?1:0,sd=new Date(_rs_Date)
	var is_det=$('#isp_details').hasClass('sel'),is_dif=$('#isp_diff').hasClass('sel'),is_per=$('#isp_percent').hasClass('sel'),isp_f
	var rd_det=$('#rd_details').hasClass('sel'),rd_dif=$('#rd_diff').hasClass('sel'),rd_per=$('#rd_percent').hasClass('sel'),rd_f
	for (var d=sd; d <= _re_Date; d.setDate(d.getDate() + 1)) {
		var dn=d.getDate(),ds=d.getFullYear()+'-'+twod(d.getMonth()+1)+'-'+twod(d.getDate()),uid="mbd-"+ds,nds=!dataset[dn]
		var down=nds?0:dataset[dn].down,up=nds?0:dataset[dn].up,ul_down=nds?0:dataset[dn].ul_down||0,ul_up=nds?0:dataset[dn].ul_up||0,dt=down+up-(ul_down+ul_up)*ul_redtot
		cTot+=dt
		dtot+=down
		utot+=up
		ul_dtot+=ul_down
		ul_utot+=ul_up
		var fd=d>today?' hidden':''
		if(!inc_all||!monthly_totals.pnd||!monthly_totals.pnd[dn]){
		}
		else{
			var flagged=monthly_totals.pnd[dn].reboots>0?' flagged':''
			var flaggedtxt=monthly_totals.pnd[dn].reboots>0?' The router was rebooted at least '+(monthly_totals.pnd[dn].reboots==1?'once':(monthly_totals.pnd[dn].reboots+' times'))+' on this date.':''
			var mtdn=monthly_totals.pnd[dn]
			rd_d=mtdn.down*1
			rd_u=mtdn.up*1
			if(rd_det){
				rd_dv=mtdn.down
				rd_uv=mtdn.up
				rd_tv=rd_dv+rd_uv
				rd_ct+=rd_tv
				rd_fdt+=rd_dv
				rd_fut+=rd_uv
				rd_ft=rd_fdt+rd_fut
				rd_f=' num'
			}
			else if(rd_dif){
				rd_dv=mtdn.dn_d
				rd_uv=mtdn.up_d
				rd_tv=rd_dv+rd_uv
				rd_ct+=rd_tv
				rd_fdt+=rd_dv
				rd_fut+=rd_uv
				rd_ft=rd_fdt+rd_fut
				rd_f=' num'
			}
			else if(rd_per){
				rd_dct+=rd_d
				rd_uct+=rd_u
				rd_dv=(mtdn.dn_p*100).toFixed(1)
				rd_uv=(mtdn.up_p*100).toFixed(1)
				rd_tv=(mtdn.t_p*100).toFixed(1)
				rd_ct='-'
				rd_f=' percent'
				rd_fdt=((rd_dct-dtot)/Math.max(dtot,1)*100).toFixed(1)
				rd_fut=((rd_uct-utot)/Math.max(utot,1)*100).toFixed(1)
				rd_ft=((rd_dct-dtot+rd_uct-utot)/Math.max(dtot+utot,1)*100).toFixed(1)
				rd_ct=rd_ft
			}
		}
		if(!inc_all||!isp_totals[dn]){
			isp_d='-';isp_dd='-';isp_dp='-';isp_dv='-'
			isp_u='-';isp_ud='-';isp_up='-';isp_uv='-'
			isp_td='-';isp_tp='-';isp_tv='-'
		}
		else{
			isp_d=isp_totals[dn].down*1
			isp_u=isp_totals[dn].up*1
			isp_dd=isp_d-down
			isp_ud=isp_u-up
			isp_dp=down==0?'-':((isp_d-down)/Math.max(down,1)*100).toFixed(1)
			isp_up=up==0?'-':((isp_u-up)/Math.max(up,1)*100).toFixed(1)
			isp_dct+=isp_d
			isp_uct+=isp_u
			if(is_det){
				isp_dv=isp_d
				isp_uv=isp_u
				isp_tv=isp_d+isp_u
				isp_ct+=isp_d+isp_u
				isp_f=' num'
				isp_fdt+=isp_dv
				isp_fut+=isp_uv
				isp_ft=isp_fdt+isp_fut
			}
			else if(is_dif){
				isp_dv=isp_dd
				isp_uv=isp_ud
				isp_tv=isp_dd+isp_ud
				isp_ct+=isp_dd+isp_ud
				isp_f=' num'
				isp_fdt+=isp_dv
				isp_fut+=isp_uv
				isp_ft=isp_fdt+isp_fut
			}
			else if(isp_percent){
				isp_dv=isp_dp
				isp_uv=isp_up
				isp_rtv=(down+up)==0?'-':(isp_d-down+isp_u-up)/Math.max(down+up,1)
				isp_tv=(down+up)==0?'-':(isp_rtv*100).toFixed(1)
				isp_rct=(down+up)==0?'-':(isp_dct-dtot+isp_uct-utot)/Math.max(dtot+utot,1)
				isp_ct=(down+up)==0?'-':(isp_rct*100).toFixed(1)
				isp_f=' percent'
				isp_fdt=dtot==0?'-':((isp_dct-dtot)/Math.max(dtot,1)*100).toFixed(1)
				isp_fut=utot==0?'-':((isp_uct-utot)/Math.max(utot,1)*100).toFixed(1)
				isp_ft=isp_ct
			}
		}
		if($('#'+uid).length==0){
			var nr=$('<tr/>').attr('id',uid).addClass('mb-row'+fd)
			nr.append($('<td/>').addClass('mbd-date a-r br bl '+flagged).text(formattedDate(d)).attr('title',flaggedtxt))
			nr.append($('<td/>').addClass('downloads num').data('value',down))
			nr.append($('<td/>').addClass('uploads num br').data('value',up))
			nr.append($('<td/>').addClass('isUL ul-down num').data('value',ul_down))
			nr.append($('<td/>').addClass('isUL ul-up num br').data('value',ul_up))
			nr.append($('<td/>').addClass('tByts br2 num').data('value',dt))
			nr.append($('<td/>').addClass('aggTot num br2').data('value',cTot*(dt>0)))
			nr.append($('<td/>').addClass('is-isp num i-d '+isp_f).data('value',isp_dv).data('v',isp_d).data('d',isp_dd).data('p',isp_dp))
			nr.append($('<td/>').addClass('is-isp num i-u br '+isp_f).data('value',isp_uv).data('v',isp_u).data('d',isp_ud).data('p',isp_up))
			nr.append($('<td/>').addClass('is-isp num i-t br2 '+isp_f).data('value',isp_tv))
			nr.append($('<td/>').addClass('is-isp num i-ct br2 '+isp_f).data('value',isp_ct))
			nr.append($('<td/>').addClass('is-rd num r-d'+rd_f).data('value',rd_dv))
			nr.append($('<td/>').addClass('is-rd num r-u br'+rd_f).data('value',rd_uv))
			nr.append($('<td/>').addClass('is-rd num r-t br2'+rd_f).data('value',rd_tv))
			nr.append($('<td/>').addClass('is-rd num r-ct br'+rd_f).data('value',rd_ct))
			$('#MonthlyBreakdown').append(nr)
		}
		else{
			var arr=[[' .downloads',down],[' .uploads',up],[' .ul-down',ul_down],[' .ul-up',ul_up],[' .tByts',dt],[' .aggTot',cTot]]
			if(inc_isp){
				$('#'+uid+' .is-isp').removeClass('percent isNull Kbytes MBytes GBytes').addClass(isp_f)
				arr.push([' .i-d',isp_dv],[' .i-u',isp_uv],[' .i-t',isp_tv],[' .i-ct',isp_ct])
			}
			if(inc_rd){
				$('#'+uid+' .is-rd').removeClass('percent isNull Kbytes MBytes GBytes').addClass(rd_f)
				arr.push([' .r-d',rd_dv],[' .r-u',rd_uv],[' .r-t',rd_tv],[' .r-ct',rd_ct])
			}
			updateRow('#'+uid,arr)
		}
	}
	var mo=twod(_cr_Date.getMonth()+1),yr=_cr_Date.getFullYear()
	for(var day in corrections){
		var c_u=corrections[day].up*1,c_d=corrections[day].down*1,desc=corrections[day].desc+' (download -> '+c_d+'MB; upload -> '+c_u+'MB)'
		$('#mbd-'+yr+'-'+mo+'-'+twod(day)+' .mbd-date').addClass('corrected').attr('title',desc)
	}
	if($('#breakdownFooter').html().length==0){
		var nr=$('<tr/>').attr('id','bdFooter')
		nr.append($('<td/>').text(':::Totals:::').addClass('a-r br bl'))
		nr.append($('<td/>').addClass('downloads num').data('value',dtot))
		nr.append($('<td/>').addClass('uploads num br').data('value',utot))
		nr.append($('<td/>').addClass('isUL ul-down num').data('value',ul_dtot))
		nr.append($('<td/>').addClass('isUL ul-up num br').data('value',ul_utot))
		nr.append($('<td/>').addClass('tByts br2 num').data('value',cTot))
		nr.append($('<td/>').text('-').addClass('a-c br2'))
		nr.append($('<td/>').addClass('is-isp isp-dt downloads num '+isp_f).data('value',isp_fdt))
		nr.append($('<td/>').addClass('is-isp isp-ut uploads num br '+isp_f).data('value',isp_fut))
		nr.append($('<td/>').addClass('is-isp isp-t tByts num br2 '+isp_f).data('value',isp_ft))
		nr.append($('<td/>').text('-').addClass('is-isp a-c br2 '+isp_f))
		nr.append($('<td/>').addClass('is-rd r-d downloads num'+rd_f).data('value',rd_fdt))
		nr.append($('<td/>').addClass('is-rd r-u uploads num br'+rd_f).data('value',rd_fut))
		nr.append($('<td/>').addClass('is-rd r-t td-t tByts num br2'+rd_f).data('value',rd_ft))
		nr.append($('<td/>').text('-').addClass('is-rd a-c br'+rd_f))
		$('#breakdownFooter').append(nr)
	}
	else{
		var arr=[[' .downloads',dtot],[' .uploads',utot],[' .ul-down',ul_dtot],[' .ul-up',ul_utot],[' .tByts',cTot]]
		if(inc_isp){
			$('#bdFooter .is-isp').removeClass('percent isNull Kbytes MBytes GBytes').addClass(isp_f)
			arr.push([' .isp-dt',isp_fdt],[' .isp-ut',isp_fut],[' .isp-t',isp_ft])
		}
		if(inc_rd){
			$('#bdFooter .is-rd').removeClass('percent isNull Kbytes MBytes GBytes').addClass(rd_f)
			arr.push([' .r-d',rd_fdt],[' .r-u',rd_fut],[' .r-t',rd_ft])
		}
		updateRow('#bdFooter',arr)
	}
	displayBytes('#MonthlyBreakdown,#breakdownFooter')
	$('.mbd-date').unbind('click').click(function(){
		var dt=$(this).parent('tr').attr('id').split('-')
		//$('#DailyData').html('')
		$('#DailyData .is_d').addClass('clear')
		_cr_Date=new Date(dt[1],dt[2]-1,dt[3])
		$('.selected').removeClass('selected')
		$('#daily-tab').removeClass('loaded').addClass('selected')
		var hourlyLoaded = loadHourly()
	})
	$('#Monthly-breakdown-table .is-isp')[inc_isp&&inc_all?'removeClass':'addClass']('hidden');
	$('.is-rd')[inc_rd&&inc_all?'removeClass':'addClass']('hidden');
	$('.isUL')[_unlimited_usage=='1'?'show':'hide']()
}
function setLiveUpdates(){
	if(Object.keys(devices).length==0)return
	$.ajax({
		method: "GET",
		url: _liveFileName,
		headers: { 'Cache-Control':'no-cache, no-store' }
	})
	.done(function( script,textStatus ) {
		$('.p-hr .icon').attr('title', 'View the contents of this `live` data file').data('link', _liveFileName)
		var tt=last_update.split(' ')[1]
		curr_users_totals(tt)
		if(_doCurrConnections==1) activeConnections()
		old_last_update=last_update
		nLiveReadFailures=0
		$('#last_update').text(last_update)
	})
	.fail(function( jqxhr,settings,exception ) {
		nLiveReadFailures++
		$('#last_update').text('error reading live data')
		var msg='<p>Error #'+nLiveReadFailures+' reading the LiveUsage data file: `<a href="'+_liveFileName+'" target="_blank">'+_liveFileName+'</a>`\n'+exception+'</p>'
		if(nLiveReadFailures>3){
			ShowAlert(msg,'live-error')
			nLiveReadFailures=0
		}
		else{
			setTimeout(function(){setLiveUpdates()},1500)
		}
	})
}
function activeConnections(){
	if(_doCurrConnections==0) return
	var filterIP=$('.filterIP:first').text()
	$('.clear-filter,.p-filterIP')[filterIP==''?'fadeOut':'fadeIn']('slow')
	$('#act-cons-body').html('')
	var	slic=$('#show-internal').is(':checked')
	var replace = ($('#acc-filter-ip').val()).replace(/[\s,]/g,"|")
	var re = new RegExp(replace,"g");
	$(curr_connections).sort(byIP).each(function (a, b) {
		if (!b[1]) return
		var sip = b[1].replace(/\:0/gi, ":"),dip = b[3]
		if (!dip) return
		if (filterIP == '' || filterIP == sip || filterIP == dip) {
			
			var int_s=sip.match(re),int_d=dip.match(re)
			var slon=!!int_s&&!!int_d?'internal':''
			var nr = $('#blank-acon-row').clone(true,true).removeAttr('id').removeClass('hidden').addClass(slon+' '+ b[0])
			nr.find('.src-ip').text(ip2device[sip] || 'unknown: ' + sip).attr('title', sip)
			nr.find('.sprt').text(b[2])
			nr.find('.dest-ip').attr('data-ip', dip).attr('data-ipn', ip2i(dip)).addClass('nomatch')
			nr.find('.dprt').text(b[4])
			nr.find('.num').data('value',b[5]).text(b[5])
			nr.appendTo('#act-cons-body')
		}
	})
	$('.dest-ip:visible').each(function(){
		var nip=$(this).data('ipn'), found=null
		$.each(g_SortedCIDR, function(a,b){
			if(b.lower<=nip && nip<b.upper){
				found=b.id
				return false
			}
			else if(b.lower>=nip){
				return false
			}
		})
		if(!found) return
		var otherips=$('.nomatch').filterIP(g_IPii[found].lower,g_IPii[found].upper)
		otherips.html(g_IPii[found].org).addClass('ipfnd').removeClass('nomatch').addClass(g_IPii[found].country).attr('data-org', g_IPii[found].org).attr('data-city', g_IPii[found].city).attr('data-country', g_IPii[found].country)

	})
	$('.settings-cb').each(function(){
		var wo=($(this).text()).toLowerCase(),ic=g_Settings['show-'+wo]
		$('.legend.'+wo).attr('data-count',$('.acon-row.'+wo).length)
	})

	$('.legend.internal').attr('data-count',$('.acon-row.internal').length)
	//$('.ipfnd').unbind('click') 

	$('#acrc').text($('.acon-row:visible').length)
	if(filterIP!=''){
		$('#acc-filter-num').text($('.acon-row:visible').length)
		$('#acc-filter-name').text($('.filter:first .cu-o').text()+'-'+$('.filter:first .cu-d').text())
		$('#acc-filter').slideDown('slow')
	}
}
function curr_users(arr){
	var tt=last_update.split(' ')[1]
	if(old_last_update==last_update) return
	var mac=arr.mac.toLowerCase(), dg=!devices[mac]?'Unknown group':devices[mac].group, dn=!devices[mac]?'Unknown device':devices[mac].name
	var tt_id='cu-'+tt.replace(/:/gi,'-')
	var dt=old_last_update?(Date.parse(last_update)-Date.parse(old_last_update))/1000:_updatefreq
	var fltr=arr.ip==$('.filterIP:first').text()?' filter':''
	var nr=$('#blank-cu').clone(true,true).removeAttr('id').attr('ip',arr.ip).attr('data-mac',arr.mac).attr('title',arr.ip).addClass('p-cu '+tt_id+fltr).removeClass('hidden')
	nr.find('.cu-o').text(dg)
	nr.find('.cu-d').text(dn)
	nr.find('.cu_do').data('value',arr.down)
	nr.find('.cu_do_ps').text((arr.down/dt/g_toKB).toFixed(_dec))
	nr.find('.cu_up').data('value',arr.up)
	nr.find('.cu_up_ps').text((arr.up/dt/g_toKB).toFixed(_dec))
	nr.prependTo('#curr-users')
	ip2device[arr.ip]=dn
}
function curr_users4(arr){
	var tt=last_update.split(' ')[1]
	if(old_last_update==last_update) return
	var id=arr.id.split('-')
	var mac=id[0].toLowerCase(), ip=id[1].toLowerCase(), dg=!devices[mac]?'Unknown group':devices[mac].group, dn=!devices[mac]?'Unknown device':devices[mac].name
	//var mac=arr.mac.toLowerCase(), dg=!devices[mac]?'Unknown group':devices[mac].group, dn=!devices[mac]?'Unknown device':devices[mac].name
	var tt_id='cu-'+tt.replace(/:/gi,'-')
	var dt=old_last_update?(Date.parse(last_update)-Date.parse(old_last_update))/1000:_updatefreq
	var fltr=ip==$('.filterIP:first').text()?' filter':''
	var nr=$('#blank-cu').clone(true,true).removeAttr('id').attr('ip',ip).attr('data-mac',id[0]).attr('title',ip).addClass('p-cu '+tt_id+fltr).removeClass('hidden')
	nr.find('.cu-o').text(dg)
	nr.find('.cu-d').text(dn)
	var down=arr.down*1-(!live[arr.id]||!live[arr.id].down?0:live[arr.id].down)
	var up=arr.up*1-(!live[arr.id]||!live[arr.id].up?0:live[arr.id].up)
	nr.find('.cu_do').data('value',down)
	nr.find('.cu_do_ps').text((down/dt/g_toKB).toFixed(_dec))
	nr.find('.cu_up').data('value',up)
	nr.find('.cu_up_ps').text((up/dt/g_toKB).toFixed(_dec))
	nr.prependTo('#curr-users')
	ip2device[ip]=dn
	$('.no-current-users').remove()
	live[arr.id]={'down':arr.down, 'up':arr.up}
}
function curr_users_totals(tt){
	var dt=old_last_update?(Date.parse(last_update)-Date.parse(old_last_update))/1000:_updatefreq
	var tt_id='cu-'+tt.replace(/:/gi,'-')
	if($('#'+tt_id).length>0) return
	var ncu=$('.'+tt_id).length
	if(ncu==0) return
	$('#curc').text(ncu + " Current Device" + (ncu==1?"":'s'))
	var t_do=0,t_up=0
	$('.'+tt_id).each(function(){
		t_do+=$(this).find('.cu_do').data('value')*1
		t_up+=$(this).find('.cu_up').data('value')*1
	})
	var nr=$('#blank-cu-tot').clone(true,true).attr('id',tt_id).addClass(tt_id).removeClass('hidden')
	nr.find('.td-time').text(tt).attr('title', last_update + ' / ' + dt )
	nr.find('.cu-o').text('# devices: '+ncu)
	nr.find('.cu-d').text('# connections: '+(curr_connections.length-1))
	nr.find('.cu_do').data('value',t_do)
	nr.find('.kbs-do').text((t_do/dt/g_toKB).toFixed(_dec))
	nr.find('.cu_up').data('value',t_up)
	nr.find('.kbs-up').text((t_up/dt/g_toKB).toFixed(_dec))
	nr.prependTo('#curr-users')
	$('#curr-users-gt').data('value',$('#curr-users-gt').data('value')*1+dt)
	$('#cu-gt-do').data('value',$('#cu-gt-do').data('value')*1+t_do)
	$('#cu-gt-up').data('value',$('#cu-gt-up').data('value')*1+t_up)
	$('#cu-kbs-do').text(($('#cu-gt-do').data('value')/$('#curr-users-gt').data('value')/g_toKB).toFixed(_dec))
	$('#cu-kbs-up').text(($('#cu-gt-up').data('value')/$('#curr-users-gt').data('value')/g_toKB).toFixed(_dec))
	numLU++
	displayBytes('.'+tt_id+',#curr-users-gt,.p-cu-tot:first')
	if($('.p-cu-tot').length>($('#hmUpdateRows').val()*1+1)){
		var l_id=$('.p-cu-tot:last').attr('id')
		$('#'+l_id+',.'+l_id).remove()
	}
	if (!livekbs_do) return
	livekbs_do.addRow([tt,$('#curr-users .kbs-do:first').text()*1,$('#cu-kbs-do').text()*1])
	var do_options={width:475,height:300,backgroundColor: { fill:inDarkMode?darkmodeBG:'transparent'},chartArea: {width: '80%',height: '73%'},title:'Live Downloads (in KB/s)',curveType:'function',fontSize:9,legend:{position:'top',fontSize:14},isStacked:true,hAxis:{title:'Time',fontSize:14,slantedText:true,titleTextStyle:{color:'green'}},vAxis:{title:'Usage in KB/s',fontSize:14,titleTextStyle:{color:'green'},viewWindow:{min:0}},series:{0:{lineWidth:1,color:'red',visibleInLegend:true},1:{lineWidth:1,color:'green',visibleInLegend:true}}}
	livekbs_do_chart.draw(livekbs_do,do_options)

	if (!livekbs_up) return
	livekbs_up.addRow([tt,$('#curr-users .kbs-up:first').text()*1,$('#cu-kbs-up').text()*1])
	var up_options={width:475,height:300,backgroundColor: { fill:inDarkMode?darkmodeBG:'transparent'},chartArea: {width: '80%',height: '73%'},title:'Live Uploads (in KB/s)',curveType:'function',fontSize:9,legend:{position:'top',fontSize:14},isStacked:true,hAxis:{title:'Time',fontSize:14,slantedText:true,titleTextStyle:{color:'green'}},vAxis:{title:'Usage in KB/s',fontSize:14,titleTextStyle:{color:'green'},viewWindow:{min:0}},series:{0:{lineWidth:1,color:'blue',visibleInLegend:true},1:{lineWidth:1,color:'purple',visibleInLegend:true}}}
	livekbs_up_chart.draw(livekbs_up,up_options)
}
function serverload(l1,l5,l15){
	var _processors=1
	$('#sp_1minSL').text(l5.toFixed(2)).css('left','calc('+(Math.min(100,$('#sp_1minSL').text()*100))+'% - 6px)')
	$('#sp_5minSL').text(l1.toFixed(2)).css('left','calc('+(Math.min(100,$('#sp_5minSL').text()*100))+'% - 1.25px)')
	$('#sp_15minSL').text(l15.toFixed(2)).css('left','calc('+(Math.min(100,$('#sp_15minSL').text()*100))+'% - 6px)')
	var speed=1000,easing='swing'
	var tt=last_update.split(' ')[1]
	var tt_id=tt.replace(/:/gi,'-')
	if(old_last_update==last_update) return
	if($('#'+tt_id).length==0){
		var tr=$('<p/>').attr('id',tt_id).addClass('p-tr hidden')
		tr.append($('<span/>').addClass('td-time br a-r').text(tt))
		tr.append($('<span/>').addClass('td-num ls-m1').text(l1.toFixed(2)))
		tr.append($('<span/>').addClass('td-num ls-m5').text(l5.toFixed(2)))
		tr.append($('<span/>').addClass('td-num ls-m15').text(l15.toFixed(2)))
		$('#liveServer').prepend(tr)
		$('#luReset').fadeIn('slow')
		$('#liveServer p').first().animate({opacity: 'toggle',height: 'toggle'},speed,easing)
		if($('#liveServer p').length>$('#hmUpdateRows').val()*1+1){
			$('#liveServer p').last().remove()
		}
	}
	if (!s_usage) return
	s_usage.addRow([tt,l1,l5,l15])
	var serverloadoptions={width:475,height:300,backgroundColor: { fill:inDarkMode?darkmodeBG:'transparent'},chartArea: {width: '80%',height: '73%'},title:'Average Server Load',curveType:'function',fontSize:9,legend:{position:'top',fontSize:14},isStacked:true,hAxis:{title:'Time',fontSize:14,slantedText:true,titleTextStyle:{color:'green'}},vAxis:{title:'Load',fontSize:14,titleTextStyle:{color:'green'},viewWindow:{min:0}},series:{0:{lineWidth:1,color:'blue',visibleInLegend:true},1:{lineWidth:1,color:'green',visibleInLegend:true},2:{lineWidth:1,color:'red',visibleInLegend:true}}};
	sl_chart.draw(s_usage,serverloadoptions)
}
function setDevices(){

	function updateUserRow(d){
		var id=d.replace(/:/g,""),nm=!monthly[d],dn=nm?0:monthly[d].down*1,up=nm?0:monthly[d].up*1,tot=dn+up, wd=$('#dd-'+id),dd=devices[d]
		wd.find('.group').text()!=dd.group && wd.find('.group').addClass('achanged').text(dd.group)
		wd.find('.thedevice').text()!=dd.name && wd.find('.thedevice').addClass('achanged').text(dd.name)
		//wd.find('.deviceIP').text()!=dd.ip && wd.find('.deviceIP').addClass('achanged').text(dd.ip)
		wd.find('.tByts').data('value')!=tot && wd.find('.tByts').addClass('changed').data('value',tot)
		if(devices[d].updated=='')
			wd.find('.updated').text(lastmod(dd.added,''))				
		else
			wd.find('.updated').text(lastmod(dd.updated,dd.added))
	}
	function filterIPs(list,ch){
		var newlist=[]
		$.each(list, function(a,b){
			if(b.indexOf(ch)<0 ) return
			newlist.push(b)
			//console.log(a,b, b.indexOf(':'))
		})
		return newlist
	}
	if($('#devices-tab').hasClass('not-selected')) return
	var ul_redtot=$('#ul-redtot').is(':checked')?1:0
	var dt_total=0
	$('#devices-tab').removeClass('loaded')
	$('.achanged').removeClass('achanged')
	Object.keys(devices).sort(byName).forEach(function(d){
		var id=devices[d].id,nm=!monthly[d],dn=nm?0:monthly[d].down*1,up=nm?0:monthly[d].up*1,tot=dn+up
		if(_unlimited_usage=='1'){
			var ul_up=nm?0:monthly[d].ul_up*1,ul_dn=nm?0:monthly[d].ul_down*1,tot=up+dn-(ul_up+ul_dn)*ul_redtot
		}
		var cs_edit=!g_Settings['devices'][d]?'':' cs_edit'
		var tcolour=devices[d].colour==''?colours_list[devices[d].n%n_colours]:devices[d].colour
		if($('#dd-'+id).length==0){
			var ud=devices[d].name, u_d=devices[d].cn,is_z=tot==0?' is_z':''
			var dih=(!devices[d].hidden)?'':' hidden-device'
			var nr=$('#blank-devices-row').clone(true,true).detach().attr('id','dd-'+id).attr('data-mac',d).attr('data-g-n',devices[d].cg+'-'+devices[d].cn).addClass('is_dd c-p'+is_z+cs_edit + dih).removeClass('hidden')
			nr.find('.group').text(devices[d].group)
			nr.find('.legend-colour').css('background-color',tcolour)
			nr.find('.thedevice').text(ud)
			nr.find('.deviceIP').text(filterIPs(devices[d].ip,'.'))
			nr.find('.deviceIPv6').text(filterIPs(devices[d].ip,':'))
			nr.find('.deviceMAC').text(d)
			nr.find('.tByts').attr('data-value',tot)
			//nr.find('.updated').text(lastmod(devices[d].updated,devices[d].added)).attr('title','updated:'+devices[d].updated+'/ last seen:'+devices[d].last_seen)
			if(devices[d].updated=='')
				nr.find('.updated').text(lastmod(devices[d].added,'')).attr('title','added: '+devices[d].added)				
			else
				nr.find('.updated').text(lastmod(devices[d].updated,devices[d].added)).attr('title','updated: '+devices[d].updated)

			nr.appendTo('#devicesData')
		}
		else{
			updateUserRow(d)
		}
		dt_total+=tot
	})
	$('#sp_num_devices').text($('.is_dd').length)
	$('#numhiddenDevices').text($('.hidden-device').length)
	$('.hiddenDevices')[$('.hidden-device').length>0?'show':'hide']()
	var nad=$('.is_dd').length-$('.is_dd.is_z').length
	$('#sp_num_active_devices').text(nad==0?'None':(nad==$('.is_dd').length?'All':nad))
	$('#dt_total').data('value',dt_total)
	setPercents('#devicesData tr',dt_total)
	displayBytes('#devices-table')
	hiddenDevices()
	var col=g_Settings['sort-devices']||0, sort_order=1
	if(col=='-0'||col<0){
		col=-col
		sort_order=-1
	}
	$('#devicesHeader tr').children('th').eq(col).addClass('sort-'+(sort_order==1?'a':'d'))
	$('#devicesData tr.odd').removeClass('odd')
	sortDevices(col,sort_order)
	$('#devicesData tr:visible:odd').addClass('odd')
}

function y_a(m){
	//console.log(m)
}
function dgt(m){
	//console.log(m)
}

function mac2group(m){
	//console.log('mac2group')
	
	function CheckGroup(group){
		if (!!names[group]) return
		var cg=clean(group)
		var n=Object.keys(names).length
		names[cg]={n:n,group:group,down:0,up:0,ul_down:0,ul_up:0,usage:[]}
	}
	function CheckMac(mac, group){
		if (!!devices[mac]) return
		var uid=mac.replace(/:/g,"")
		var n=Object.keys(devices).length, cg=clean(group)
		devices[mac]={n:n,id:uid,group:group,cg:cg,colour:'',name:'',cn:'',ip:[],active:'0',added:'',updated:''}
	}
	var mac=m.mac.toLowerCase(), group=(!!g_Settings['devices'][mac])?g_Settings['devices'][mac].group:m.group
	CheckGroup(group)
	CheckMac(mac,group)
	if (!!g_Settings['devices'][mac] && group!=m.group) devices[mac].router_group=m.group
}

function mac2ip(d){
	//console.log('mac2ip')
	var id=d.id.split('-'), mac=id[0].toLowerCase()
	if(!devices[mac]){
		//console.log('no device for'+mac)
		var n=Object.keys(devices).length, group='Huh', cg='Huh', uid=mac.replace(/:/g,"")
		devices[mac]={n:n,id:uid,group:group,cg:cg,colour:'',name:'',cn:'',ip:[],active:'0',added:'',updated:''}
	}
	var name=(!!g_Settings['devices'][mac])?g_Settings['devices'][mac].name:d.name
	devices[mac].name=name
	devices[mac].ip.push(id[1])
	devices[mac].cn=clean(name)
	devices[mac].active=d.active
	devices[mac].added=d.added
	devices[mac].updated=d.updated
	if (!!g_Settings['devices'][mac] && name!=d.name) devices[mac].router_name=d.name
}

function totalDaily(arr){
	//totalDaily({ "id":"00:18:61:28:36:3f-192.168.1.244", "day":"05", "traffic":"2812818,3516409,173517,0" })
	var id=arr.id.split('-'), mac=id[0].toLowerCase(), ip=id[1], dn=1*arr.day, traff=arr.traffic.split(',')
	if (!monthly[mac]) monthly[mac]={down:0,up:0,ul_down:0,ul_up:0,usage:{}}
	monthly[mac].down+=1*traff[0]||0
	monthly[mac].up+=1*traff[1]||0
	monthly[mac].ul_down+=1*traff[2]||0
	monthly[mac].ul_up+=1*traff[3]||0
	monthly[mac].usage[dn]={down:1*traff[0]||0,up:1*traff[1]||0,ul_down:1*traff[2]||0,ul_up:1*traff[3]||0}
}
function hourlyData4(arr){ 
	//hourlyData4({ "id":"d8:58:d7:00:45:4c-192.168.0.10", "hour":"07", "traffic":"25404,17483" })
	var id=arr.id.split('-'), mac=id[0].toLowerCase(), ip=id[1], hr=1*arr.hour, traff=arr.traffic.split(',')
	if (!hourly[mac]) hourly[mac]={down:0,up:0,ul_down:0,ul_up:0,usage:{}}
	hourly[mac].down+=1*traff[0]||0
	hourly[mac].up+=1*traff[1]||0
	hourly[mac].ul_down+=1*traff[2]||0
	hourly[mac].ul_up+=1*traff[3]||0
	hourly[mac].usage[hr]={down:1*traff[0]||0,up:1*traff[1]||0,ul_down:1*traff[2]||0,ul_up:1*traff[3]||0}
}

function drawSummaryGauges(du, mem){
	var du=(du.replace('%','')*1)
	var m=mem.split(',')
	$("#sp-freeMem").text(mem[0])
	if (!google||!google.visualization||!google.visualization.arrayToDataTable){
		//console.log('Error - google.visualization.arrayToDataTable')
	}
	else{
		var mf=((1-(m[0])/m[2])*100).toFixed(0)
		var ma=((1-(m[1])/m[2])*100).toFixed(0)

		gauges=new google.visualization.Gauge(document.getElementById('gauges'));
		var data=google.visualization.arrayToDataTable([['Label','Value'],['Disk',du*1],['Avail.',ma*1],['Memory',mf*1]])
		var gaugeOptions={animation:{duration:2000,easing:'inAndOut'},width:200,height:80,greenFrom:0,greenTo:74,yellowFrom:75,yellowTo:90,redFrom:90,redTo:100,minorTicks:5}
		gaugeOptions.width=300
		gauges.draw(data,gaugeOptions)
	}
	$("#gauges td:first").attr('title','Disk Utilization: '+du+'%')
	$("#gauges td:nth-child(2)").attr('title','Available Memory: '+ma+'% ('+m[1]+' bytes)')
	$("#gauges td:last").attr('title','Memory Utilization: '+mf+'% ('+m[0]+' bytes free)')
}
	
function Totals(arr){
	//Totals({ "hour":"00", "uptime":"1940773.59", "interval":"570322357,8898462","interfaces":'[ {"n":"guest_turris_0", "t":"336,0"}, {"n":"wlan0", "t":"62402580,1547435"}, {"n":"eth1", "t":"1328688,59660357"}, {"n":"wlan1", "t":"238778,52878"}, {"n":"br-lan", "t":"61414914,1516318"}, {"n":"br-guest_turris", "t":"0,0"}]',"memory":'{19452,712680,1030692}',"disk_utilization":'61%' })
	//if (!hourly[mac]) hourly[mac]={down:0,up:0,ul_down:0,ul_up:0,usage:{}}
	var hr=1*arr.hour, traff=arr.interval.split(',')
	hourly_totals.usage[hr]={ down:1*traff[0]||0,up:1*traff[1]||0}
	var ifl=JSON.parse(arr.interfaces)
	ifl.forEach(function(a,b){
		var tin=a.n, tt=a.t.split(',')
		if (!interfaces[tin]) interfaces[tin]={down:0,up:0,usage:{}}
		interfaces[tin].down+=tt[0]*1
		interfaces[tin].up+=tt[1]*1
		interfaces[tin].usage[hr]={'down':tt[0]*1, 'up':tt[1]*1}
	})
	var o2u=!!interfaces['br0']?interfaces['br0']:interfaces['br-lan']
	if (!o2u) o2u={'down':0,'up':0,'usage':[]}
	//var pnd_data={'start':{'down':0,'up':0},'total':{'down':0,'up':0,'dropped':0,'local':0,'lost':0},'usage':[]}
	pnd_data.total.down+=o2u.down
	pnd_data.total.up+=o2u.up
	pnd_data.usage=o2u.usage
	var mem=(arr.memory).replace(/[{}]/g,"").split(',')
	hourly_totals.memory[hr]=mem
	drawSummaryGauges(arr.disk_utilization, arr.memory )
	$('#uptime').text(sec2text(arr.uptime))

}

function GrandTotalDaily(arr){
	//GrandTotalDaily({ "day":"05", "traffic":"6535513460,397009700,215338171,15483" })
	var dn=1*arr.day, traff=arr.traffic.split(','), ifl=[]
	monthly_totals.down+=1*traff[0]||0
	monthly_totals.up+=1*traff[1]||0
	monthly_totals.ul_down+=1*traff[2]||0
	monthly_totals.ul_up+=1*traff[3]||0
	monthly_totals.usage[dn]={down:1*traff[0]||0,up:1*traff[1]||0,ul_down:1*traff[2]||0,ul_up:1*traff[3]||0}
	if(!!arr.interfaces) ifl=JSON.parse(arr.interfaces)
	ifl.forEach(function(a,b){
		var tin=a.n, tt=a.t.split(',')
		if (!monthly_totals.interfaces[tin]) monthly_totals.interfaces[tin]={down:0,up:0,usage:{}}
		monthly_totals.interfaces[tin].down+=tt[0]*1
		monthly_totals.interfaces[tin].up+=tt[1]*1
		monthly_totals.interfaces[tin].usage[dn]={'down':tt[0]*1, 'up':tt[1]*1}
	})
	var o2u=!!monthly_totals.interfaces['br0']?monthly_totals.interfaces['br0']:monthly_totals.interfaces['br-lan']
	//var pnd_data={'start':{'down':0,'up':0},'total':{'down':0,'up':0,'dropped':0,'local':0,'lost':0},'usage':[]}
	if (!o2u) return
	pnd_data.total.down+=o2u.down
	pnd_data.total.up+=o2u.up
	pnd_data.usage[dn]=o2u.usage[dn]
}
