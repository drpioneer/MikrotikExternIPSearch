# external ip address search script (in case of double-nat)
# tested on ROS 6.49.18 & 7.19.1
# updated 2025/09/15

:do {
  # search of interface-list gateway
  :local GwFinder do={ # no input parameters
    :local routeISP [/ip route find dst-address=0.0.0.0/0 active=yes]; :if ([:len $routeISP]=0) do={:return ""}
    :set routeISP "/ip route get $routeISP"; /interface
    :local routeGW {"[$routeISP vrf-interface]";"[$routeISP immediate-gw]";"[$routeISP gateway-status]"}
    :foreach ifLstMmb in=[list member find] do={
      :local ifIfac [list member get $ifLstMmb interface]; :local ifList [list member get $ifLstMmb list]
      :local brName ""; :do {:set brName [bridge port get [find interface=$ifIfac] bridge]} on-error={}
      :foreach answer in=$routeGW do={
        :local gw ""; :do {:set gw [:tostr [[:parse $answer]]]} on-error={}
        :if ([:len $gw]>0 && $gw~$ifIfac or [:len $brName]>0 && $gw~$brName) do={:return $ifIfac}}}
    :return ""}

  # external IP address return function # https://forummikrotik.ru/viewtopic.php?p=65345#p65345
  :local ExtIP do={
    :local addr {
      {mode="http"; url="checkip.amazonaws.com"};
      {mode="http"; url="icanhazip.com"};
      {mode="http"; url="checkip.dyndns.org"};
    }

    # function of cutting out unnecessary characters # https://forum.mikrotik.com/viewtopic.php?p=714396#p714396
    :local ConvSymb do={
      :if ([:typeof $1]!="str" or [:len $1]=0) do={:return ""}
      :local allowSymb "0123456789."; :local res ""
      :for i from=0 to=([:len $1]-1) do={
        :local chr [:pick $1 $i]
        :local pos [:find $allowSymb $chr]; :if ($pos>-1) do={} else={:set chr ""}
        :set res ($res.$chr)}
      :return $res}

    :local resp ""
    :foreach payLoad in=$addr do={
      :put "Request data from '$($payLoad->"mode")://$($payLoad->"url")'";
      :do {:set resp [/tool fetch mode=($payLoad->"mode") url="$($payLoad->"mode")://$($payLoad->"url")" as-value output=user]} on-error={}
      :if ([:len $resp]!=0) do={
        :local content [$ConvSymb ($resp->"data")]; :put "Response received: '$content'"
        :if ($content~"((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)[.]){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)") do={
          :return [[:parse ":return $content"]]}
      } else={:put "No response received"}}
    :return "Unknown"}

  :put "Start of external ip address search script on router: $[/system identity get name]"
  :local currIP [$ExtIP]; :local currGW [$GwFinder]; 
  :put "External IP: '$currIP'; Gateway: $currGW"
}
