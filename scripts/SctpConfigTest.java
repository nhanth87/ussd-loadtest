import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlElementWrapper;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlProperty;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlRootElement;
import com.fasterxml.jackson.dataformat.xml.ser.ToXmlGenerator;
import com.fasterxml.jackson.databind.SerializationFeature;

import java.util.*;

public class SctpConfigTest {
    public static void main(String[] args) throws Exception {
        XmlMapper mapper = new XmlMapper();
        mapper.configure(ToXmlGenerator.Feature.WRITE_XML_DECLARATION, true);
        mapper.enable(SerializationFeature.INDENT_OUTPUT);
        mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);

        SctpPersistData data = new SctpPersistData();
        data.connectDelay = 5000;
        data.congControl_DelayThreshold_1 = 2.5;
        data.congControl_DelayThreshold_2 = 8.0;
        data.congControl_DelayThreshold_3 = 14.0;

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
        data.associations = new HashMap<>();
        data.associations.put("ass1", assoc);

        String xml = mapper.writeValueAsString(data);
        System.out.println("========== SCTPManagement_sctp.xml ==========");
        System.out.println(xml);
    }

    @JacksonXmlRootElement(localName = "sctp")
    @JsonInclude(JsonInclude.Include.NON_NULL)
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
}
