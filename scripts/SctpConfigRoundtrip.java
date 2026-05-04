import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlElementWrapper;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlProperty;
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlRootElement;
import com.fasterxml.jackson.dataformat.xml.ser.ToXmlGenerator;
import com.fasterxml.jackson.databind.SerializationFeature;

import java.util.*;

public class SctpConfigRoundtrip {
    public static void main(String[] args) throws Exception {
        XmlMapper mapper = new XmlMapper();
        mapper.configure(ToXmlGenerator.Feature.WRITE_XML_DECLARATION, true);
        mapper.enable(SerializationFeature.INDENT_OUTPUT);
        mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);
        mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        // Test format 1: <associations><association name="ass1">...</association></associations>
        String xml1 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<sctp>\n" +
            "  <connectdelay>5000</connectdelay>\n" +
            "  <servers>\n" +
            "    <server name=\"serv1\" hostAddress=\"127.0.0.1\" hostport=\"8012\" started=\"true\" ipChannelType=\"SCTP\" acceptAnonymousConnections=\"false\" maxConcurrentConnectionsCount=\"0\"/>\n" +
            "  </servers>\n" +
            "  <associations>\n" +
            "    <association name=\"ass1\" hostAddress=\"127.0.0.1\" hostPort=\"8012\" peerAddress=\"127.0.0.1\" peerPort=\"8011\" serverName=\"serv1\" ipChannelType=\"SCTP\" type=\"SERVER\"/>\n" +
            "  </associations>\n" +
            "</sctp>";

        System.out.println("=== Testing Format 1 (attributes) ===");
        try {
            SctpPersistData d1 = mapper.readValue(xml1, SctpPersistData.class);
            System.out.println("Parse OK! connectDelay=" + d1.connectDelay);
            System.out.println("servers size=" + (d1.servers != null ? d1.servers.size() : "null"));
            if (d1.servers != null && !d1.servers.isEmpty()) {
                System.out.println("server[0].name=" + d1.servers.get(0).name);
            }
            System.out.println("associations size=" + (d1.associations != null ? d1.associations.size() : "null"));
            if (d1.associations != null && !d1.associations.isEmpty()) {
                for (Map.Entry<String, AssociationImpl> e : d1.associations.entrySet()) {
                    System.out.println("  assoc[" + e.getKey() + "].name=" + e.getValue().name + ", hostAddress=" + e.getValue().hostAddress);
                }
            }
        } catch (Exception e) {
            System.out.println("Parse FAILED: " + e.getMessage());
            e.printStackTrace();
        }

        // Test format 2: <associations><ass1>...</ass1></associations>
        String xml2 = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<sctp>\n" +
            "  <connectdelay>5000</connectdelay>\n" +
            "  <servers>\n" +
            "    <server>\n" +
            "      <name>serv1</name>\n" +
            "      <hostAddress>127.0.0.1</hostAddress>\n" +
            "      <hostport>8012</hostport>\n" +
            "      <started>true</started>\n" +
            "    </server>\n" +
            "  </servers>\n" +
            "  <associations>\n" +
            "    <ass1>\n" +
            "      <hostAddress>127.0.0.1</hostAddress>\n" +
            "      <hostPort>8012</hostPort>\n" +
            "      <peerAddress>127.0.0.1</peerAddress>\n" +
            "      <peerPort>8011</peerPort>\n" +
            "      <name>ass1</name>\n" +
            "    </ass1>\n" +
            "  </associations>\n" +
            "</sctp>";

        System.out.println("\n=== Testing Format 2 (elements as keys) ===");
        try {
            SctpPersistData d2 = mapper.readValue(xml2, SctpPersistData.class);
            System.out.println("Parse OK! connectDelay=" + d2.connectDelay);
            System.out.println("associations size=" + (d2.associations != null ? d2.associations.size() : "null"));
            if (d2.associations != null && !d2.associations.isEmpty()) {
                for (Map.Entry<String, AssociationImpl> e : d2.associations.entrySet()) {
                    System.out.println("  assoc[" + e.getKey() + "].name=" + e.getValue().name);
                }
            }
        } catch (Exception e) {
            System.out.println("Parse FAILED: " + e.getMessage());
            e.printStackTrace();
        }
    }

    @JacksonXmlRootElement(localName = "sctp")
    @JsonInclude(JsonInclude.Include.NON_NULL)
    static class SctpPersistData {
        @JsonProperty("connectdelay") public Integer connectDelay;
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
