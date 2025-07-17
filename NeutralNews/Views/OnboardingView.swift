//
//  OnboardingView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/07/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var showPaywall = false
    private let totalPages = 3
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<totalPages, id: \.self) { index in
                onboardingPage(for: index)
                    .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) {
            Button("Saltar") {
                isPresented = false
            }
            .font(.body)
            .foregroundStyle(.blue)
            .padding()
        }
        .overlay(alignment: .bottom) {
            if currentPage == totalPages - 1 {
                Button {
                    showPaywall = true
                } label: {
                    Text("Comenzar")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showPaywall) {
            isPresented = false
        } content: {
            PaywallView(isPresented: $showPaywall)
        }
    }
    
    @ViewBuilder
    private func onboardingPage(for index: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Group {
                switch index {
                case 0:
                    firstPage
                case 1:
                    secondPage
                case 2:
                    thirdPage
                default:
                    EmptyView()
                }
            }
            .multilineTextAlignment(.center)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private var firstPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "newspaper.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.bounce, value: currentPage == 0)
            
            VStack(spacing: 12) {
                Text("Todo en un solo lugar")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Descubre las noticias más relevantes de distintos medios españoles, todas en un solo lugar y sin sesgos.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var secondPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "scale.3d")
                .font(.system(size: 80))
                .foregroundStyle(.green.gradient)
                .symbolEffect(.pulse, value: currentPage == 1)
            
            VStack(spacing: 12) {
                Text("Algoritmo anti-sesgo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Nuestro algoritmo analiza diversas fuentes y genera resúmenes claros y neutrales para que puedas informarte de forma objetiva.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var thirdPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(.orange.gradient)
                .symbolEffect(.wiggle, value: currentPage == 2)
            
            VStack(spacing: 12) {
                Text("Compara los medios")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Descubre cómo distintos medios cuentan una misma noticia y compara sus versiones de un vistazo.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
