import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.dataformat.xml.ser.ToXmlGenerator;

import java.io.StringWriter;
import java.util.*;

public class GenerateConfig {
    public static void main(String[] args) throws Exception {
        generateSctpConfig();
        generateM3uaConfig();
    }

    static void generateSctpConfig() throws Exception {
        XmlMapper mapper = new XmlMapper();
        mapper.configure(ToXmlGenerator.Feature.WRITE_XML_DECLARATION, true);
        mapper.enable(SerializationFeature.INDENT_OUTPUT);

        // Build SCTP config as nested maps
        Map<String, Object> sctp = new LinkedHashMap<>();
        sctp.put("connectdelay", 5000);
        sctp.put("congControl_DelayThreshold_1", 2.5);
        sctp.put("congControl_DelayThreshold_2", 8.0);
        sctp.put("congControl_DelayThreshold_3", 14.0);
        sctp.put("congControl_BackToNormalDelayThreshold_1", 1.5);
        sctp.put("congControl_BackToNormalDelayThreshold_2", 5.5);
        sctp.put("congControl_BackToNormalDelayThreshold_3", 10.0);

        Map<String, Object> server = new LinkedHashMap<>();
        server.put("name", "serv1");
        server.put("hostAddress", "127.0.0.1");
        server.put("hostport", 8012);
        server.put("started", true);
        server.put("ipChannelType", "SCTP");
        server.put("acceptAnonymousConnections", false);
        server.put("maxConcurrentConnectionsCount", 0);

        List<Map<String, Object>> servers = new ArrayList<>();
        servers.add(server);
        sctp.put("servers", servers);

        Map<String, Object> assoc = new LinkedHashMap<>();
        assoc.put("hostAddress", "127.0.0.1");
        assoc.put("hostPort", 8012);
        assoc.put("peerAddress", "127.0.0.1");
        assoc.put("peerPort", 8011);
        assoc.put("serverName", "serv1");
        assoc.put("name", "ass1");
        assoc.put("ipChannelType", "SCTP");
        assoc.put("type", "SERVER");

        Map<String, Object> associations = new LinkedHashMap<>();
        associations.put("ass1", assoc);
        sctp.put("associations", associations);

        String xml = mapper.writeValueAsString(sctp);
        System.out.println("========== SCTPManagement_sctp.xml ==========");
        System.out.println(xml);
    }

    static void generateM3uaConfig() throws Exception {
        XmlMapper mapper = new XmlMapper();
        mapper.configure(ToXmlGenerator.Feature.WRITE_XML_DECLARATION, true);
        mapper.enable(SerializationFeature.INDENT_OUTPUT);

        Map<String, Object> m3ua = new LinkedHashMap<>();
        m3ua.put("timeBetweenHeartbeat", 10000);
        m3ua.put("statisticsEnabled", false);
        m3ua.put("statisticsTaskDelay", 5000);
        m3ua.put("statisticsTaskPeriod", 5000);
        m3ua.put("routingKeyManagementEnabled", false);
        m3ua.put("useLsbForLinksetSelection", false);

        Map<String, Object> aspFactory = new LinkedHashMap<>();
        aspFactory.put("name", "asp1");
        aspFactory.put("assocName", "ass1");
        aspFactory.put("started", true);
        aspFactory.put("maxseqnumber", 256);
        aspFactory.put("aspid", 2);
        aspFactory.put("heartbeat", false);

        List<Map<String, Object>> aspFactoryList = new ArrayList<>();
        aspFactoryList.add(aspFactory);
        m3ua.put("aspFactoryList", aspFactoryList);

        Map<String, Object> as = new LinkedHashMap<>();
        as.put("name", "as1");
        as.put("minAspActiveForLb", 1);
        as.put("functionality", "IPSP");
        as.put("exchangeType", "SE");
        as.put("ipspType", "SERVER");

        Map<String, Object> rc = new LinkedHashMap<>();
        rc.put("value", 101);
        List<Map<String, Object>> routingContext = new ArrayList<>();
        routingContext.add(rc);
        as.put("routingContext", routingContext);

        as.put("networkAppearance", 102);
        as.put("trafficMode", 2);
        as.put("defTrafficMode", 2);

        Map<String, Object> aspRef = new LinkedHashMap<>();
        aspRef.put("name", "asp1");
        List<Map<String, Object>> asps = new ArrayList<>();
        asps.add(aspRef);
        as.put("asps", asps);

        List<Map<String, Object>> asList = new ArrayList<>();
        asList.add(as);
        m3ua.put("asList", asList);

        Map<String, Object> routeEntry = new LinkedHashMap<>();
        routeEntry.put("key", "1:2:3");
        routeEntry.put("value", Map.of("trafficModeType", 2, "as", "as1"));

        List<Map<String, Object>> route = new ArrayList<>();
        route.add(routeEntry);
        m3ua.put("route", route);

        String xml = mapper.writeValueAsString(m3ua);
        System.out.println("\n========== Mtp3UserPart_m3ua1.xml ==========");
        System.out.println(xml);
    }
}
