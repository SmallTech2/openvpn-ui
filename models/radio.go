package models

import (
	"fmt"
	"net"

	"github.com/beego/beego/v2/server/web"
	clientconfig "github.com/d3vilh/openvpn-server-config/client/client-config"
	easyrsaconfig "github.com/d3vilh/openvpn-server-config/easyrsa/config"
	serverconfig "github.com/d3vilh/openvpn-server-config/server/config"
)

// RadioNetwork retourne le reseau du VPS ; nil conserve le comportement hors Radio.
func RadioNetwork() (*net.IPNet, error) {
	network := web.AppConfig.DefaultString("RadioVpnNetwork", "")
	if network == "" {
		return nil, nil
	}
	if network != "10.1.0.0" && network != "10.2.0.0" && network != "10.3.0.0" {
		return nil, fmt.Errorf("RadioVpnNetwork doit etre 10.1.0.0, 10.2.0.0 ou 10.3.0.0")
	}
	publicIP := net.ParseIP(web.AppConfig.DefaultString("RadioPublicIP", ""))
	if publicIP == nil || publicIP.To4() == nil || publicIP.IsUnspecified() || publicIP.IsLoopback() || publicIP.IsMulticast() {
		return nil, fmt.Errorf("RadioPublicIP doit contenir l'IPv4 du VPS")
	}
	_, subnet, err := net.ParseCIDR(network + "/16")
	return subnet, err
}

// Ces valeurs sont aussi appliquees aux sauvegardes GUI pour eviter les anciens defauts.
func ApplyRadioServerConfig(c *serverconfig.Config) error {
	subnet, err := RadioNetwork()
	if err != nil || subnet == nil {
		return err
	}
	c.Device = "tun0"
	c.OVConfigTopology = "subnet"
	c.Server = "server " + subnet.IP.String() + " 255.255.0.0 nopool"
	c.Route, c.PushRoute, c.RedirectGW = "", "", ""
	c.DNSServer1, c.DNSServer2 = "", ""
	c.CustomOptTwo = "client-to-client\nccd-exclusive"
	return nil
}

func ApplyRadioClientConfig(c *clientconfig.Config) error {
	subnet, err := RadioNetwork()
	if err != nil || subnet == nil {
		return err
	}
	c.ServerAddress = web.AppConfig.DefaultString("RadioPublicIP", "")
	c.RedirectGateway = ""
	return nil
}

func ApplyRadioEasyRSAConfig(c *easyrsaconfig.Config) error {
	subnet, err := RadioNetwork()
	if err != nil || subnet == nil {
		return err
	}
	c.EasyRSAReqCountry = "FR"
	c.EasyRSAReqProvince, c.EasyRSAReqCity = "BR", "Pleneuf-Val-Andre"
	c.EasyRSAReqOrg = web.AppConfig.DefaultString("RadioPKIOrganization", "Radio Bonheur")
	c.EasyRSAReqEmail = web.AppConfig.DefaultString("RadioPKIEmail", "contact@radiobonheur.com")
	c.EasyRSAReqOu = "VPN " + subnet.IP.String()
	return nil
}
