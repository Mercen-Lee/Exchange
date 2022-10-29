//
//  ContentView.swift
//  Exchange
//
//  Created by Mercen on 2022/10/29.
//

import SwiftUI
import Alamofire

// MARK: - 화폐 종류 enum
enum ExchangeType: String, CaseIterable {
    case krw = "한국(KRW)"
    case usd = "미국(USD)"
    case jpy = "일본(JPY)"
    case php = "필리핀(PHP)"
}

// MARK: - 숫자와 점만 입력 가능한 ObservedObject
class NumbersOnly: ObservableObject {
    @Published var str = "0" {
        didSet {
            let filtered = str.filter { $0.isNumber || $0 == "." }
            if str != filtered {
                str = filtered
            }
        }
    }
}

// MARK: -JSON 디코딩 구조체
struct ExchangeData: Decodable, Hashable {
    let quotes: [String: Double]
    let source: String
    let success: Bool
    let timestamp: Double
}

struct ContentView: View {
    
    // MARK: - API 키 설정
    let apiKey: String = ""
    
    @ObservedObject var value = NumbersOnly()
    
    // MARK: - 값 변수
    @State var types: [ExchangeType] = [.usd, .krw]
    @State var finalValue: Double = 0
    @State var currentBalance: Double?
    @State var fetchedTime: Double?
    
    // MARK: - 이벤트 변수
    @State var buttonClicked: Bool = false
    @State var errorOccurred: Bool = false
    @State var wrongValue: Bool = false
    
    // MARK: - 숫자 포맷 함수
    func comma(_ original: Double) -> String {
        let numberFormatter = NumberFormatter()
        
        numberFormatter.numberStyle = .decimal
        numberFormatter.roundingMode = .floor
        numberFormatter.maximumFractionDigits = 2
        
        var returnData = numberFormatter.string(from: NSNumber(value: original))!
        let components = returnData.components(separatedBy: ".")
        
        if components.count == 1 {
            returnData = "\(returnData).00"
        } else if components[1].count == 1 {
            returnData = "\(returnData)0"
        }
        
        return returnData
    }
    
    // MARK: - enum을 String로 변경
    var typeStrings: [String] {
        var returnData: [String] = [String]()
        
        for type in types {
            returnData.append(String(describing: type).uppercased())
        }
        
        return returnData
    }
    
    // MARK: - 환율 정보 포맷
    var balanceString: String {
        if currentBalance == nil {
            return "로딩 중..."
        } else {
            let returnData = comma(currentBalance!)
            return "\(returnData) \(typeStrings[1]) / \(typeStrings[0])"
        }
    }
    
    // MARK: - 호출 시 유닉스 시간을 포맷
    var timeString: String {
        if fetchedTime == nil {
            return "로딩 중..."
        } else {
            let date = Date(timeIntervalSince1970: fetchedTime!)
            
            let dayTimePeriodFormatter = DateFormatter()
            dayTimePeriodFormatter.dateFormat = "YYYY-MM-dd / hh:mm:ss"
            
            return dayTimePeriodFormatter.string(from: date)
        }
    }
    
    // MARK: - API 호출 함수
    func load() {
        AF.request("https://api.apilayer.com/currency_data/live",
                   method: .get,
                   parameters: ["source": typeStrings[0],
                                "currencies": typeStrings[1]],
                   headers: ["apiKey": apiKey]
        ) { $0.timeoutInterval = 5 }
            .validate()
            .responseData { response in
                switch response.result {
                case .success:
                    guard let value = response.value else { return }
                    guard let result = try?
                            JSONDecoder().decode(ExchangeData.self,
                                                 from: value) else { return }
                    withAnimation(.default) {
                        currentBalance = Array(result.quotes.values)[0]
                        fetchedTime = result.timestamp
                    }
                case .failure(let error):
                    print("통신 오류!\nCode:\(error._code), Message: \(error.errorDescription!)")
                    errorOccurred.toggle()
                }
            }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("환율 계산하기")) {
                    
                    // MARK: - 송금 국가, 수취 국가 선택
                    ForEach(0..<2) { idx in
                        HStack {
                            
                            Image(typeStrings[idx])
                                .resizable()
                                .frame(width: 16, height: 11)
                            
                            Picker("\(["송금", "수취"][idx])국가", selection: $types[idx]) {
                                ForEach(ExchangeType.allCases, id: \.self) { type in
                                    if types[[1, 0][idx]] != type {
                                        Text(type.rawValue)
                                            .tag(type)
                                    }
                                }
                            }
                            
                        }
                        .onChange(of: types) { _ in
                            value.str = "0"
                            withAnimation(.default) {
                                currentBalance = nil
                                fetchedTime = nil
                                buttonClicked = false
                                load()
                            }
                        }
                    }
                    
                    // MARK: - 환율과 조회 시간
                    ForEach(0..<2) { idx in
                        HStack {
                            Text(["환율", "조회시간"][idx])
                            Spacer()
                            Text([balanceString, timeString][idx])
                        }
                    }
                    
                    // MARK: - 송금액
                    HStack(spacing: 4) {
                        Text("송금액")
                        Spacer()
                        TextField("", text: $value.str)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: value.str) { _ in
                                withAnimation(.default) {
                                    buttonClicked = false
                                }
                            }
                        Text(typeStrings[0])
                    }
                    
                    // MARK: - 수취 금액 결과
                    if buttonClicked {
                        HStack {
                            Text("수취 금액")
                            Spacer()
                            Text(.init("**\(comma(finalValue))** \(typeStrings[1])"))
                        }
                    }
                    
                    // MARK: - 환율 계산 버튼
                    Button(action: {
                        if Double(value.str)! == 0 || Double(value.str)! > 10000 {
                            wrongValue.toggle()
                        } else {
                            withAnimation(.default) {
                                finalValue = Double(value.str)! * currentBalance!
                                buttonClicked = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("환율 계산")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 50)
                        .background(Color.accentColor)
                    }
                    .listRowInsets(EdgeInsets())
                    .buttonStyle(.borderless)
                    .disabled(currentBalance == nil)
                }
            }
            .navigationTitle("환율 계산")
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: load)
        
        // MARK: - 서버 오류 처리
        .alert(isPresented: $errorOccurred) {
            Alert(title: Text("오류"),
                  message: Text("서버에 연결할 수 없습니다"),
                  dismissButton: Alert.Button.default(Text("확인"), action: {
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    exit(0)
                }
            }))
        }
        
        // MARK: - 송금액 오류 처리
        .alert(isPresented: $wrongValue) {
            Alert(title: Text("오류"),
                  message: Text("송금액이 바르지 않습니다"),
                  dismissButton: .default(Text("확인"))
            )
        }
    }
}
