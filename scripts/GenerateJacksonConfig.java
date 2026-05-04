import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlElementWrapper;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlProperty;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlRootElement;
import com.fasterxml.jackson.dataformat.xml.ser.ToXmlGenerator;

import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

public class GenerateJacksonConfig {
    public static void main(String[] args) throws Exception {
        generateSctpConfig();
        generateM3uaConfig();
    }

    static void generateSctpConfig() throws Exception {
        XmlMapper mapper = new XmlMapper();
        mapper.configure(ToXmlGenerator.Feature.WRITE_XML_DECLARATION, true);
        mapper.enable(SerializationFeature.INDENT_OUTPUT);
        mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);
        mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        SctpPersistData data = new SctpPersistData();
        data.connectDelay = 5000;
        data.congControl_DelayThreshold_1 = 2.5;
        data.congControl_DelayThreshold_2 = 8.0;
        data.congControl_DelayThreshold_3 = 14.0;
        data.congControl_BackToNormalDelayThreshold_1 = 1.5;
        data.congControl_BackToNormalDelayThreshold_2 = 5.5;
        data.congControl_BackToNormalDelayThreshold_3 = 10.0;

        ServerImpl server = new ServerImpl();
        server.name = "serv1";
        server.hostAddress = "127.0.0.1";
        server.hostport = 8012;
        server.started = true;
        server.ipChannelType = "SCTP";
        server.acceptAnonymousConnections = false;
        server.maxConcurrentConnectionsCount = 0;
        data.servers = new ArrayList<>();
        data.servers.add(server);

        AssociationImpl assoc = new AssociationImpl();
        assoc.hostAddress = "127.0.0.1";
        assoc.hostPort = 8012;
        assoc.peerAddress = "127.0.0.1";
        assoc.peerPort = 8011;
        assoc.serverName = "serv1";
        assoc.name = "ass1";
        assoc.ipChannelType = "SCTP";
        assoc.type = "SERVER";
        data.associations = new LinkedHashMap<>();
        data.associations.put("ass1", assoc);

        String xml = mapper.writeValueAsString(data);
        System.out.println("========== SCTPManagement_sctp.xml ==========");
        System.out.println(xml);
        System.out.println();
    }

    static void generateM3uaConfig() throws Exception {
        XmlMapper mapper = new XmlMapper();
        mapper.configure(ToXmlGenerator.Feature.WRITE_XML_DECLARATION, true);
        mapper.enable(SerializationFeature.INDENT_OUTPUT);
        mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);
        mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        M3UAConfig config = new M3UAConfig();
        config.timeBetweenHeartbeat = 10000;
        config.statisticsEnabled = false;
        config.statisticsTaskDelay = 5000;
        config.statisticsTaskPeriod = 5000;
        config.routingKeyManagementEnabled = false;
        config.useLsbForLinksetSelection = false;

        AspFactoryImpl aspFactory = new AspFactoryImpl();
        aspFactory.name = "asp1";
        aspFactory.started = true;
        aspFactory.associationName = "ass1";
        config.aspFactories = new CopyOnWriteArrayList<>();
        config.aspFactories.add(aspFactory);

        AsImpl as = new AsImpl();
        as.name = "as1";
        as.minAspActiveForLb = 1;

        RoutingContextImpl rc = new RoutingContextImpl();
        rc.rcs = new long[]{101};
        as.routingContext = rc;

        TrafficModeTypeImpl tm = new TrafficModeTypeImpl();
        tm.mode = 2;
        as.trafficModeType = tm;
        as.defaultTrafficModeType = tm;

        AspImpl asp = new AspImpl();
        asp.name = "asp1";
        asp.aspFactoryName = "asp1";
        asp.asName = "as1";
        as.appServerProcs = new ArrayList<>();
        as.appServerProcs.add(asp);

        config.appServers = new CopyOnWriteArrayList<>();
        config.appServers.add(as);

        RouteEntry routeEntry = new RouteEntry();
        routeEntry.key = "1:2:3";
        RouteAsImpl routeAs = new RouteAsImpl();
        routeAs.trafficModeType = tm;
        routeAs.asArraytemp = "as1";
        routeEntry.value = routeAs;

        config.routeEntries = new ArrayList<>();
        config.routeEntries.add(routeEntry);

        String xml = mapper.writeValueAsString(config);
        System.out.println("========== Mtp3UserPart_m3ua1.xml ==========");
        System.out.println(xml);
        System.out.println();
    }

    // ===== SCTP POJOs =====
    @JacksonXmlRootElement(localName = "sctp")
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    static class SctpPersistData {
        @JsonProperty("connectdelay") public Integer connectDelay;
        @JsonProperty("congControl_DelayThreshold_1") public Double congControl_DelayThreshold_1;
        @JsonProperty("congControl_DelayThreshold_2") public Double congControl_DelayThreshold_2;
        @JsonProperty("congControl_DelayThreshold_3") public Double congControl_DelayThreshold_3;
        @JsonProperty("congControl_BackToNormalDelayThreshold_1") public Double congControl_BackToNormalDelayThreshold_1;
        @JsonProperty("congControl_BackToNormalDelayThreshold_2") public Double congControl_BackToNormalDelayThreshold_2;
        @JsonProperty("congControl_BackToNormalDelayThreshold_3") public Double congControl_BackToNormalDelayThreshold_3;

        @JacksonXmlElementWrapper(localName = "servers")
        @JacksonXmlProperty(localName = "server")
        public List<ServerImpl> servers;

        @JacksonXmlElementWrapper(localName = "associations")
        @JacksonXmlProperty(localName = "association")
        public Map<String, AssociationImpl> associations;
    }

    @JacksonXmlRootElement(localName = "server")
    static class ServerImpl {
        @JsonProperty("name") public String name;
        @JsonProperty("hostAddress") public String hostAddress;
        @JsonProperty("hostport") public int hostport;
        @JsonProperty("started") public boolean started;
        @JsonProperty("ipChannelType") public String ipChannelType;
        @JsonProperty("acceptAnonymousConnections") public boolean acceptAnonymousConnections;
        @JsonProperty("maxConcurrentConnectionsCount") public int maxConcurrentConnectionsCount;
    }

    @JacksonXmlRootElement(localName = "association")
    static class AssociationImpl {
        @JsonProperty("hostAddress") public String hostAddress;
        @JsonProperty("hostPort") public int hostPort;
        @JsonProperty("peerAddress") public String peerAddress;
        @JsonProperty("peerPort") public int peerPort;
        @JsonProperty("serverName") public String serverName;
        @JsonProperty("name") public String name;
        @JsonProperty("ipChannelType") public String ipChannelType;
        @JsonProperty("type") public String type;
    }

    // ===== M3UA POJOs =====
    @JacksonXmlRootElement(localName = "m3uaConfig")
    @JsonIgnoreProperties(ignoreUnknown = true)
    static class M3UAConfig {
        @JsonProperty("timeBetweenHeartbeat") public int timeBetweenHeartbeat;
        @JsonProperty("statisticsEnabled") public boolean statisticsEnabled;
        @JsonProperty("statisticsTaskDelay") public long statisticsTaskDelay;
        @JsonProperty("statisticsTaskPeriod") public long statisticsTaskPeriod;
        @JsonProperty("routingKeyManagementEnabled") public boolean routingKeyManagementEnabled;
        @JsonProperty("useLsbForLinksetSelection") public boolean useLsbForLinksetSelection;

        @JsonProperty("aspFactories")
        @JacksonXmlElementWrapper(localName = "aspFactoryList")
        @JacksonXmlProperty(localName = "aspFactory")
        public CopyOnWriteArrayList<AspFactoryImpl> aspFactories;

        @JsonProperty("appServers")
        @JacksonXmlElementWrapper(localName = "asList")
        @JacksonXmlProperty(localName = "as")
        public CopyOnWriteArrayList<AsImpl> appServers;

        @JsonProperty("routeEntries")
        @JacksonXmlElementWrapper(localName = "route")
        @JacksonXmlProperty(localName = "routeEntry")
        public ArrayList<RouteEntry> routeEntries;
    }

    @JacksonXmlRootElement(localName = "aspFactory")
    static class AspFactoryImpl {
        @JsonProperty("name") @JacksonXmlProperty(isAttribute = true) public String name;
        @JsonProperty("started") @JacksonXmlProperty(isAttribute = true) public boolean started;
        @JsonProperty("assocName") @JacksonXmlProperty(isAttribute = true) public String associationName;
    }

    @JacksonXmlRootElement(localName = "as")
    static class AsImpl {
        @JsonProperty("minAspActiveForLb") @JacksonXmlProperty(isAttribute = true) public int minAspActiveForLb;
        @JsonProperty("name") public String name;
        @JsonProperty("routingContext") public RoutingContextImpl routingContext;
        @JsonProperty("trafficModeType") public TrafficModeTypeImpl trafficModeType;
        @JsonProperty("defaultTrafficModeType") public TrafficModeTypeImpl defaultTrafficModeType;
        @JsonProperty("appServerProcs") public List<AspImpl> appServerProcs;
    }

    @JacksonXmlRootElement(localName = "routingContext")
    static class RoutingContextImpl {
        @JsonProperty("rcs") public long[] rcs;
    }

    @JacksonXmlRootElement(localName = "trafficModeType")
    static class TrafficModeTypeImpl {
        @JsonProperty("mode") public int mode;
    }

    @JacksonXmlRootElement(localName = "asp")
    static class AspImpl {
        @JsonProperty("name") @JacksonXmlProperty(isAttribute = true) public String name;
        @JsonProperty("aspFactoryName") @JacksonXmlProperty(isAttribute = true) public String aspFactoryName;
        @JsonProperty("asName") @JacksonXmlProperty(isAttribute = true) public String asName;
    }

    static class RouteEntry {
        @JsonProperty("key") public String key;
        @JsonProperty("value") public RouteAsImpl value;
    }

    @JacksonXmlRootElement(localName = "routeAs")
    static class RouteAsImpl {
        @JsonProperty("trafficModeType") public TrafficModeTypeImpl trafficModeType;
        @JsonProperty("asArraytemp") public String asArraytemp;
    }
}
